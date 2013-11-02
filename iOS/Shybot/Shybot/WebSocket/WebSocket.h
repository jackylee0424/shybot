//
//  WebSocket.h
//
//  Originally created for Zimt by Esad Hajdarevic on 2/14/10.
//  Copyright 2010 OpenResearch Software Development OG. All rights reserved.
//
//  Erich Ocean made the code more generic.
//
//  Tobias Rodäbel implemented support for draft-hixie-thewebsocketprotocol-76.
//

#import <Foundation/Foundation.h>

@class AsyncSocket;
@class WebSocket;

@protocol WebSocketDelegate<NSObject>
@optional
    - (void)webSocket:(WebSocket*)webSocket didFailWithError:(NSError*)error;
    - (void)webSocketDidOpen:(WebSocket*)webSocket;
    - (void)webSocketDidClose:(WebSocket*)webSocket;
    - (void)webSocket:(WebSocket*)webSocket didReceiveMessage:(NSString*)message;
    - (void)webSocketDidSendMessage:(WebSocket*)webSocket;
    - (void)webSocketDidSecure:(WebSocket*)webSocket;
@end

@interface WebSocket : NSObject {
    id<WebSocketDelegate> delegate;
    NSURL *url;
    AsyncSocket *socket;
    BOOL connected;
    BOOL secure;
    NSString *origin;
    NSData *expectedChallenge;
    NSArray* runLoopModes;
}

@property(nonatomic,assign) id<WebSocketDelegate> delegate;
@property(nonatomic,readonly) NSURL *url;
@property(nonatomic,retain) NSString *origin;
@property(nonatomic,readonly) BOOL connected;
@property(nonatomic,readonly) BOOL secure;
@property(nonatomic,retain) NSData *expectedChallenge;
@property(nonatomic,retain) NSArray *runLoopModes;

+ (id)webSocketWithURLString:(NSString *)urlString delegate:(id<WebSocketDelegate>)delegate;
- (id)initWithURLString:(NSString *)urlString delegate:(id<WebSocketDelegate>)delegate;

- (void)open;
- (void)close;
- (void)send:(NSString*)message;

@end

enum {
    WebSocketErrorConnectionFailed = 1,
    WebSocketErrorHandshakeFailed = 2
};

extern NSString * const WebSocketException;
extern NSString * const WebSocketErrorDomain;
