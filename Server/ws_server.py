#!/usr/local/bin python

import os
import tornado.httpserver
import tornado.ioloop
import tornado.websocket
import tornado.options
import tornado.web
from tornado.options import define, options
import simplejson
import base64
import random
import json
import httplib
import logging

define("port", default=8765, help="run on the given port", type=int) ## 8124

class WSViewHandler(tornado.web.RequestHandler):
    def get(self):
        self.write("""
            <html>
            <head>
             <script src="//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js" ></script>
             <script type="text/javascript">
            
                var ws = new WebSocket("ws://192.168.1.121:8765/wsb");
                
                ws.onopen = function()
                {
                };
                
                ws.onmessage = function (evt)
                {
                    var r_data = JSON.parse(evt.data);
                    document.getElementById("wsimg").src = unescape(r_data["base64ImageDataUrl"]);
                };
            
            </script>
            </head>
            <body>
                <div id='images' style='position:absolute;top:20px;left:20px'>
                    <img id="wsimg" width=120 />
                </div>
            </body>
            </html>
            """)

class WSBroadcastHandler(tornado.websocket.WebSocketHandler):
    waiters = set()
    cache=[]
    cache_size=200
    
    @classmethod
    def update_cache(cls, chat):
        cls.cache.append(chat)
        if len(cls.cache) > cls.cache_size:
            cls.cache = cls.cache[-cls.cache_size:]
    
    @classmethod
    def send_updates(cls, chat):
        logging.info("sending message to %d waiters", len(cls.waiters))
        for waiter in cls.waiters:
            try:
                waiter.write_message(chat)
            except:
                logging.error("Error sending message", exc_info=True)
    
    def open(self):
        self.waiters.add(self)
        print "WebSocket opened"
    
    def on_close(self):
        try:
            self.waiters.remove(self)
            print "WebSocket closed"
        except:
            print "Oops!"
    
    def on_message(self, message):
        parsed = tornado.escape.json_decode(message)
        #print parsed
        #self.update_cache(message)
        self.send_updates(message)

class WSocketHandler(tornado.websocket.WebSocketHandler):
    def open(self):
        print "ws opened"
    
    def on_message(self, message):
        parsed = tornado.escape.json_decode(message)
        #self.write_message(dict(msg="server echo"))
        self.write_message(parsed)
    
    def on_close(self):
        print "ws closed"

class MainHandler(tornado.web.RequestHandler):
    def get(self):
        self.write(dict(msg=1))

class ErrorHandler(tornado.web.RequestHandler):
    def __init__(self, application, request, status_code):
        tornado.web.RequestHandler.__init__(self, application, request)
        self.set_status(status_code)
    
    def get_error_html(self, status_code, **kwargs):
        self.require_setting("static_path")
        return "<html><head><title>%(code)d: %(message)s :(</title>" \
                "</head><body style='padding:60px'>"\
                "<div id='er404'><h1>Oops... %(message)s (%(code)d)</h1></div></body></html>" % {
                "code": status_code,
                "message": httplib.responses[status_code],
    }
    
    def prepare(self):
        raise tornado.web.HTTPError(self._status_code)

settings = {
    "static_path": os.path.join(os.path.dirname(__file__), "static"),
    "debug":True,
}

def main():
    tornado.options.parse_command_line()
    tornado.web.ErrorHandler = ErrorHandler
    application = tornado.web.Application([
                                           (r"/",MainHandler),
                                           (r"/ws",WSocketHandler),
                                           (r"/wsb",WSBroadcastHandler),
                                           (r"/view",WSViewHandler),
                                           
                                           ], **settings)
    http_server = tornado.httpserver.HTTPServer(application)
    http_server.listen(options.port)
    tornado.ioloop.IOLoop.instance().start()


if __name__ == "__main__":
    main()
