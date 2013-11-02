//
//  WebSocket.m
//
//  Originally created for Zimt by Esad Hajdarevic on 2/14/10.
//  Copyright 2010 OpenResearch Software Development OG. All rights reserved.
//
//  Erich Ocean made the code more generic.
//
//  Tobias Rodäbel implemented support for draft-hixie-thewebsocketprotocol-76.
//

#import "WebSocket.h"
#import "AsyncSocket.h"

#import <CommonCrypto/CommonDigest.h>

// Set this to 1 if you are running in secure mode on a box without a valid cert
#define WEBSOCKET_DEV_MODE 1

NSString * const WebSocketErrorDomain = @"WebSocketErrorDomain";
NSString * const WebSocketException   = @"WebSocketException";

enum {
    WebSocketTagHandshake = 0,
    WebSocketTagMessage = 1
};

typedef struct SecKey {
    uint32_t num;
    NSString *key;
} SecKey;

#define HANDSHAKE_REQUEST @"GET %@ HTTP/1.1\r\n" \
                           "Upgrade: WebSocket\r\n" \
                           "Connection: Upgrade\r\n" \
                           "Sec-WebSocket-Protocol: sample\r\n" \
                           "Sec-WebSocket-Key1: %@\r\n" \
                           "Sec-WebSocket-Key2: %@\r\n" \
                           "Host: %@%@\r\n" \
                           "Origin: %@\r\n\r\n"


@interface NSData (WebSocketDataAdditions)

- (NSData *) MD5;

@end


@implementation NSData (WebSocketDataAdditions)

- (NSData *) MD5
{
    NSMutableData *digest = [NSMutableData dataWithLength:CC_MD5_DIGEST_LENGTH];

    CC_MD5([self bytes], (unsigned)[self length], [digest mutableBytes]);

    return digest;
}

@end


@implementation WebSocket

@synthesize delegate, url, origin, connected, expectedChallenge, runLoopModes, secure;

#pragma mark Initializers

+ (id)webSocketWithURLString:(NSString*)urlString delegate:(id<WebSocketDelegate>)aDelegate {
    return [[[WebSocket alloc] initWithURLString:urlString delegate:aDelegate] autorelease];
}

- (id)initWithURLString:(NSString *)urlString delegate:(id<WebSocketDelegate>)aDelegate {
    self = [super init];
    if (self) {
        self.delegate = aDelegate;
        url = [[NSURL URLWithString:urlString] retain];
        if (![url.scheme isEqualToString:@"ws"] && ![url.scheme isEqualToString:@"wss"]) {
          [NSException raise:WebSocketException format:@"Unsupported protocol %@", url.scheme];
        }
        if ([url.scheme isEqualToString:@"wss"]) {
          secure = YES;
        }
        socket = [[AsyncSocket alloc] initWithDelegate:self];
        self.runLoopModes = [NSArray arrayWithObjects:NSRunLoopCommonModes, nil];
    }
    return self;
}

#pragma mark Delegate dispatch methods

- (void)_dispatchFailure:(NSNumber*)code {
    if(delegate && [delegate respondsToSelector:@selector(webSocket:didFailWithError:)]) {
        [delegate webSocket:self didFailWithError:[NSError errorWithDomain:WebSocketErrorDomain code:[code intValue] userInfo:nil]];
    }
}

- (void)_dispatchClosed {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidClose:)]) {
        [delegate webSocketDidClose:self];
    }
}

- (void)_dispatchOpened {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidOpen:)]) {
        [delegate webSocketDidOpen:self];
    }
}

- (void)_dispatchMessageReceived:(NSString*)message {
    if (delegate && [delegate respondsToSelector:@selector(webSocket:didReceiveMessage:)]) {
        [delegate webSocket:self didReceiveMessage:message];
    }
}

- (void)_dispatchMessageSent {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidSendMessage:)]) {
        [delegate webSocketDidSendMessage:self];
    }
}

- (void)_dispatchSecured {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidSecure:)]) {
      [delegate webSocketDidSecure:self];
    }
}

#pragma mark Private

- (void)_readNextMessage {
    [socket readDataToData:[NSData dataWithBytes:"\xFF" length:1] withTimeout:-1 tag:WebSocketTagMessage];
}

- (struct SecKey)_makeKey {

    struct SecKey seckey;
    uint32_t spaces;
    uint32_t max, num, prod;
    NSInteger keylen;
    unichar letter;

    spaces = (arc4random() % 12) + 1;
    max = (arc4random() % 4294967295U) / spaces;
    num = arc4random() % max;
    prod = spaces * num;

    NSMutableString *key = [NSMutableString stringWithFormat:@"%d", prod];

    keylen = [key length];

    for (NSInteger i=0; i<12; i++) {

        if ((arc4random() % 2) == 0)
            letter = (arc4random() % (47 - 33 + 1)) + 33;
        else
            letter = (arc4random() % (126 - 58 + 1)) + 58;

        [key insertString:[[[NSString alloc] initWithCharacters:&letter length:1] autorelease] atIndex:(arc4random() % (keylen-1))];
    }

    keylen = [key length];

    for (uint32_t i=0; i<spaces; i++)
        [key insertString:@" " atIndex:((arc4random() % (keylen-2))+1)];

    seckey.num = num;
    seckey.key = key;

    return seckey;
}

- (void)_makeChallengeNumber:(uint32_t)number withBuffer:(unsigned char *)buf {

    unsigned char *p = buf + 3;

    for (int i = 0; i < 4; i++) {
        *p = number & 0xFF;
        --p;
        number >>= 8;
    }
}

#pragma mark Public interface

- (void)close {
    [socket disconnectAfterReadingAndWriting];
    //NSLog(@"websocket closed");
}

- (void)open {
    if (!connected) {
        if (secure) {
          NSDictionary *settings = nil;
          if (WEBSOCKET_DEV_MODE) {
            settings = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],
                        (NSString *)kCFStreamSSLAllowsAnyRoot, nil];
          }
          [socket startTLS:settings];
        }

        [socket connectToHost:url.host onPort:[url.port intValue] withTimeout:5 error:nil];
        if (runLoopModes) [socket setRunLoopModes:runLoopModes];
    }
}

- (void)send:(NSString*)message {
    NSMutableData* data = [NSMutableData data];
    [data appendBytes:"\x00" length:1];
    [data appendData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendBytes:"\xFF" length:1];
    [socket writeData:data withTimeout:-1 tag:WebSocketTagMessage];
}

#pragma mark AsyncSocket delegate methods

- (BOOL)onSocketWillConnect:(AsyncSocket *)sock {
  if (secure && WEBSOCKET_DEV_MODE) {
    // Connecting to a secure server
    NSMutableDictionary * settings = [NSMutableDictionary dictionaryWithCapacity:2];

    // Use the highest possible security
    [settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
                 forKey:(NSString *)kCFStreamSSLLevel];

    // Allow self-signed certificates
    [settings setObject:[NSNumber numberWithBool:YES]
                 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];

    CFReadStreamSetProperty([sock getCFReadStream],
                            kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
    CFWriteStreamSetProperty([sock getCFWriteStream],
                             kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
  }

  return YES;
}

- (void)onSocketDidSecure:(AsyncSocket *)sock {
  [self _dispatchSecured];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock {
    connected = NO;
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    if (!connected) {
        [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorConnectionFailed]];
    } else {
        [self _dispatchClosed];
    }
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {

    NSString *requestOrigin = (self.origin) ? self.origin : [NSString stringWithFormat:@"http://%@", url.host];

    NSString *requestPath = (url.query) ? [NSString stringWithFormat:@"%@?%@", url.path, url.query] : url.path;

    SecKey seckey1 = [self _makeKey];
    SecKey seckey2 = [self _makeKey];

    NSString *key1 = seckey1.key;
    NSString *key2 = seckey2.key;

    char letters[8];

    for (int i=0; i<8; i++)
        letters[i] = arc4random() % 126;

    NSData *key3 = [NSData dataWithBytes:letters length:8];

    unsigned char bytes[8];
    [self _makeChallengeNumber:seckey1.num withBuffer:&bytes[0]];
    [self _makeChallengeNumber:seckey2.num withBuffer:&bytes[4]];

    NSMutableData *challenge = [NSMutableData dataWithBytes:bytes length:sizeof(bytes)];
    [challenge appendData:key3];

    self.expectedChallenge = [challenge MD5];

    NSString *headers = [NSString stringWithFormat:HANDSHAKE_REQUEST,
                                                   requestPath,
                                                   key1,
                                                   key2,
                                                   url.host,
                                                   ((secure && [url.port intValue] != 443) ||
                                                    (!secure && [url.port intValue] != 80)) ?
                                                    [NSString stringWithFormat:@":%d", [url.port intValue]] : @"",
                                                   requestOrigin];

    NSMutableData *request = [NSMutableData dataWithData:[headers dataUsingEncoding:NSASCIIStringEncoding]];
    [request appendData:key3];

    [socket writeData:request withTimeout:-1 tag:WebSocketTagHandshake];
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
    switch (tag) {
        case WebSocketTagHandshake:
            [sock readDataToData:self.expectedChallenge withTimeout:5 tag:WebSocketTagHandshake];
            break;

        case WebSocketTagMessage:
            [self _dispatchMessageSent];
            break;

        default:
            break;
    }
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {

    if (tag == WebSocketTagHandshake) {

        NSString *upgrade;
        NSString *connection;
        NSData *body;
        UInt32 statusCode;

        CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);

        if (!CFHTTPMessageAppendBytes(message, [data bytes], [data length])) {
            [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorHandshakeFailed]];
        }

        //if (CFHTTPMessageIsHeaderComplete(message))
        {
            upgrade = [(NSString *) CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Upgrade")) autorelease];
            connection = [(NSString *) CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Connection")) autorelease];
            statusCode = (UInt32)CFHTTPMessageGetResponseStatusCode(message);
        }

        if (statusCode == 101 && [upgrade isEqualToString:@"WebSocket"] && [connection isEqualToString:@"Upgrade"]) {
            body = [(NSData *)CFHTTPMessageCopyBody(message) autorelease];

            if (![body isEqualToData:self.expectedChallenge]) {
                [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorHandshakeFailed]];
                return;
            }

            connected = YES;

            [self _dispatchOpened];
            [self _readNextMessage];
        } else {
            [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorHandshakeFailed]];
        }

    } else if (tag == WebSocketTagMessage) {

        char firstByte = 0xFF;

        [data getBytes:&firstByte length:1];

        if (firstByte != 0x00) return; // Discard message

        NSString *message = [[[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1, [data length]-2)] encoding:NSUTF8StringEncoding] autorelease];

        [self _dispatchMessageReceived:message];
        [self _readNextMessage];
    }
}

#pragma mark Destructor

- (void)dealloc {
    socket.delegate = nil;
    [socket disconnect];
    [socket release];
    [expectedChallenge release];
    [runLoopModes release];
    [url release];
    [super dealloc];
}

@end
