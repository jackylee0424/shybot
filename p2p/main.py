#!/usr/bin/env python

## TODO
# 1. test if face recog is loading block data
# 2. local dict and block syncing process (work-around)
# 3. refactor and cleaning up
# 4. test multiple full face nodes
# 5. refactor block structure
# 6. add multi-sig for familiarity measurement - be present to be friend

## face server
import os
from os.path import join
import tornado.httpserver
import tornado.ioloop
import tornado.web
import tornado.websocket
import time
import sys
import json
import numpy as np
import urllib2
import base64
import urlparse
import glob
import cv2
import pickle
import hashlib
import shutil
from sklearn.decomposition import PCA
import peer
import thread
import cPickle

total_images = 0

port = 8080
comments = dict()
users = dict()
data_dict = dict()
pca_m = None
pn = peer.Node()
ip = pn.node_ip


def CosineDistance(p, q):
    p = np.asarray(p).flatten()
    q = np.asarray(q).flatten()
    return -1 * np.dot(p.T, q) / (np.sqrt(np.dot(p, p.T) * np.dot(q, q.T)))


def preprocessimg(img_file):
    """
    preprocess images into 128 x 128
    TODO: try "Bob" lib for normalizing face/eyes

    """
    if img_file[-3:] == "png":
        img = cv2.imread(img_file)
        img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        img = cv2.resize(img, (128, 128), interpolation=cv2.INTER_CUBIC)
        img = cv2.equalizeHist(img)
        img = img.flatten("C").copy()
        return img
    else:
        return -1


## image hashing function (change to perceptual hashing)
def md5_for_file(path, block_size=256 * 128):
    md5 = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(block_size), b''):
            md5.update(chunk)
    return md5.hexdigest()


def sha256_for_file(path, block_size=256 * 128):
    sha256 = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(block_size), b''):
            sha256.update(chunk)
    return sha256.hexdigest()


def perceptualhash_for_file(img_file, hash_size=8):
    # Grayscale and shrink the image in one step.
    img = cv2.imread(img_file)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    img = cv2.resize(
        img, (hash_size + 1, hash_size), interpolation=cv2.INTER_CUBIC)
    image = img.flatten("C").copy()

    # Compare adjacent pixels.
    difference = []
    for row in xrange(hash_size):
        for col in xrange(hash_size):
            pixel_left = image[col + row * (hash_size + 1)]
            pixel_right = image[col + 1 + row * (hash_size + 1)]
            difference.append(pixel_left > pixel_right)

    # Convert the binary array to a hexadecimal string.
    decimal_value = 0
    hex_string = []
    for index, value in enumerate(difference):
        if value:
            decimal_value += 2 ** (index % 8)
        if (index % 8) == 7:
            hex_string.append(hex(decimal_value)[2:].rjust(2, '0'))
            decimal_value = 0

    return ''.join(hex_string)


def read_cvimages2dict(path):
    """
    read images into a dict structure

    """

    data_dict = dict()

    for dirname, dirnames, filenames in os.walk(path):
        for subdirname in dirnames:
            subject_path = os.path.join(dirname, subdirname)
            for filename in os.listdir(subject_path):
                try:
                    if filename[-3:] == "png":
                        fullpath = os.path.join(subject_path, filename)
                        # perceptual hash might have collison problem
                        filehash = perceptualhash_for_file(fullpath, 8)
                        filelabel = subject_path.split(path)[1][1:]
                        ts = int(filename[:-4])
                        data_dict[filehash] = dict(
                            data=preprocessimg(fullpath).tolist(),
                            label=filelabel, ts=ts)
                except:
                    print "Unexpected error:", sys.exc_info()[0]
                    raise
    return data_dict


## low pass filter using rolling average
def lowpass(x, r):
    # set rolling value from first value
    rolling = x[0]
    lpx = []
    for i in x:
        rolling = rolling * r + i * (1. - r)
        lpx.append(rolling)
    return np.array(lpx)


def project(W, X, mu=None):
    if mu is None:
        return np.dot(X, W)
    return np.dot(X - mu, W)


def predictX(
        Xin, W, mu, data_dict, labels, num_of_mins,
        projection_type, dist_type, min_dist=-.6):
    Q = project(W, Xin.reshape(1, -1), mu)
    matched_label = ""
    for ky in data_dict.keys():
        data_dict[ky][dist_type] = CosineDistance(
            data_dict[ky][projection_type], Q)
    output = dict()
    for i in sorted(
        data_dict, key=lambda x: (data_dict[x][dist_type], data_dict[x]['label']))[:num_of_mins]:

        if data_dict[i]["label"] in labels:
            cos_dist = data_dict[i][dist_type]
            if cos_dist < min_dist:
                #print "min: %f (%s)" % (cos_dist, labels[data_dict[i]["label"]])
                matched_label = data_dict[i]["label"]
                if labels[data_dict[i]["label"]] not in output:
                    output[labels[data_dict[i]["label"]]] = cos_dist
                else:
                    output[labels[data_dict[i]["label"]]] += cos_dist

    sum_dist = sum(output.values())

    if sum_dist > min_dist:
        return {"-": 0}, ""

    for i in output.keys():
        output[i] /= sum_dist
    return output, matched_label


class WSocketHandler(tornado.websocket.WebSocketHandler):
    def open(self):
        print "ws opened"
        self.dir_name = "%.0f" % (time.time() * 1000.0)
        self.mode = 0
        self.data_loaded = False
        self.pca_m = None
        self.labeldict = dict()
        self.load_data()
        
    def load_data(self):
        global pca_m
        
        if os.path.exists(join('data', 'labels.bin')):
        # load from existing file
            with open(join('data', 'labels.bin'), 'rb') as input:
                self.labeldict = pickle.load(input)
        else:
            print "no label file found"
            # create a new data file
            with open(join('data', 'labels.bin'), 'wb') as output:
                pickle.dump(self.labeldict, output, pickle.HIGHEST_PROTOCOL)

        self.pca_m = pca_m
        if self.pca_m:
            self.data_loaded = True
            print "pca model loaded"
        else:
            self.data_loaded = False
    
    def detect_face(self, img):
        output_label, matched_label = predictX(
            img, self.pca_m.components_.T, self.pca_m.mean_, data_dict,
            self.labeldict, 10, "proj_pca", "cos_dist_pca")
        self.write_message(
            json.dumps(
                dict(computed=output_label, matched_label=matched_label)
            )
        )

    def allow_draft76(self):
        # for iOS 5.0 Safari
        return False
    
    def on_message(self, message):
        parsed = tornado.escape.json_decode(message)
        self.mode = int(parsed["mode"])
        
        d = urllib2.unquote(parsed["base64Data"])
        img = base64.b64decode(d.split(',')[1])
        fname = "%.0f" % (time.time() * 1000.0)
        
        if not os.path.exists(join("data", "raw", self.dir_name)):
            os.makedirs(join("data", "raw", self.dir_name))
        
        fullpath = join("data", "raw", self.dir_name, fname + ".png")
        with open(fullpath, "wb") as f:
            f.write(img)
            print "saved to %s.png" % fname
                               
        if (self.mode > 0) and (self.data_loaded):
            print "Detect mode"
            self.detect_face(preprocessimg(fullpath))
        else:
            print "Training mode"
            self.labeldict[self.dir_name] = parsed["label"]
            print "Labels- %s" % (self.labeldict[self.dir_name])

    def on_close(self):
        #global total_images
        if (self.mode > 0):
            shutil.rmtree(join("data", "raw", self.dir_name))
        elif (self.mode < 0):
            # re-train PCA model for new training data
            initPCA()
            
        # save label pairs to disk
        if not os.path.exists("data"):
            os.makedirs("data")
        with open(join('data', 'labels.bin'), 'wb') as output:
            pickle.dump(self.labeldict, output, pickle.HIGHEST_PROTOCOL)


class CapturePageHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            try:
                label = self.get_argument('label', None, True)
                if label == '':
                    self.redirect('/new')
                self.render(
                    "face.html",
                    mode=-1, title="New User",
                    myIP=ip, label=label, myPort=port)
            except:
                self.redirect('/new')
        except:
            self.redirect('/new')


class DoneLoginPageHandler(tornado.web.RequestHandler):
    def get(self):
        try:
            label = self.get_argument('label', None, True)
            if label == '':
                self.redirect('/')
        except:
            self.redirect('/')
        self.write('''<html><head>
        <meta charset="utf-8">
        <title>Shybot</title>
        <link rel="stylesheet" href="static/css/bootstrap-combined.min.css">
            </head><body>''')
        self.write("<h2>Login Successfully, %s</h2>" % label)
        self.write("<p><a href='/'>home</a></p>")
        self.write("</body></html>")


class LoginPageHandler(tornado.web.RequestHandler):
    def get(self):
        self.render(
            "face.html", mode=1, title="Login", myIP=ip, label="", myPort=port)


class IndexPageHandler(tornado.web.RequestHandler):
    def get(self):
        self.labeldict = dict()
        if os.path.exists(join('data', 'labels.bin')):
        # load from existing file
            with open(join('data', 'labels.bin'), 'rb') as input:
                self.labeldict = pickle.load(input)
        else:
            print "no label file found"
            # create a new data file
            with open(join('data', 'labels.bin'), 'wb') as output:
                pickle.dump(self.labeldict, output, pickle.HIGHEST_PROTOCOL)
            #print self.labeldict

        self.write('''
        <html><head>
        <meta charset="utf-8">
        <title>Shybot software</title>
        <link rel="stylesheet" href="static/css/bootstrap-combined.min.css">
        </head><body style="padding-left:30px">
            ''')
        self.write("<br><h2>Shybot</h2>")
        self.write("<h4>emotion robot software</h4>")
        self.write(
            "<i>powered by distributed data-driven people-robot interaction</i><br><br>")
        self.write("total enrolled images: %d <br>" % total_images)
        self.write("total enrolled labels: %d <br>" % len(self.labeldict))
        self.write(
            "total enrolled IDs: %d <br><br>" % len(
                set([i for i in self.labeldict.values()])))
        for i in pn.allnodes:
            print type(i)
            self.write(i["node_label"] + "<br>")
        if total_images > 0:
            self.write("<p><a href='/login'>login</a></p>")
        self.write("<p><a href='/new'>new user</a></p>")
        if total_images > 0:
            self.write("<p><a href='/train'>data explorer</a></p>")
        self.write("</body></html>")


class DonePageHandler(tornado.web.RequestHandler):
    def get(self):
        self.write('''<html><head>
        <meta charset="utf-8">
        <title>Shybot</title>
        <link rel="stylesheet" href="static/css/bootstrap-combined.min.css">
        </head><body>''')
        self.write("<h2>ok</h2>")
        self.write("<p>new user database established. try login now.</p>")
        self.write("<p><a href='/login'>login</a></p><br>")
        self.write("<p><a href='/'>home</a></p>")
        self.write("</body></html>")


class NewLabelPageHandler(tornado.web.RequestHandler):
    def get(self):
        self.write('''<html><head>
        <meta charset="utf-8">
        <title>New User</title>
        <link rel="stylesheet" href="static/css/bootstrap-combined.min.css">
        <script type="text/javascript" src="static/js/jquery-1.11.0.min.js">
        </script>
        </head><body style="padding-left:30px">''')
        self.write(
            "<br><h3>New User</h3><br><b>Please enter your first name</b><br>")
        self.write("<input type='text' id='label_name' />")
        self.write("<p><a id='next_stop'>next</a></p><br><br>")
        self.write('''
        <script type="text/javascript">$("a#next_stop").on('click',function()
        {
            //alert("/cap?label="+$("#label_name").val());
            var label_name = $("#label_name").val();
            if (label_name!='')
                window.location.href = "/cap?label="+$("#label_name").val();
        });
        </script>''')
        self.write("</body></html>")


class TrainingSetHandler(tornado.web.RequestHandler):
    def post(self):
        trained_labels = dict()
        with open(join('data', 'labels.bin'), 'rb') as input:
            trained_labels = pickle.load(input)
        posted = urlparse.parse_qs(self.request.body)
        if "value" in posted:
            trained_labels[posted['pk'][0]] = posted["value"][0]
        else:
            ## delete label
            del trained_labels[posted['pk'][0]]
        with open(join('data', 'labels.bin'), 'wb') as output:
            pickle.dump(trained_labels, output, pickle.HIGHEST_PROTOCOL)

    def get(self):
        trained_labels = dict()
        with open(join('data', 'labels.bin'), 'rb') as input:
            trained_labels = pickle.load(input)

        train_set = [i.split(os.sep)[-1] for i in glob.glob("data/raw/1*")]
        self.render(
            "trainset.html", trainset=train_set, trained_labels=trained_labels)


class TrainedLabelHandler(tornado.web.RequestHandler):
    def get(self, train_label):
        for i in glob.glob("data/raw/" + train_label + "/*.png"):
            self.write("<img src='../" + i + "' width=75/>")


def initPCA():
    '''TODO- separate firstrun and block update '''
    global pca_m, data_dict, total_images

    # read images, travese all folders again (not efficient)
    data_dict = read_cvimages2dict(join("data", "raw"))

    # check block
    block = dict()
    if os.path.exists("block.blk"):
        with open('block.blk', 'rb') as f:
            block = cPickle.load(f)
    
    print "data/block", len(data_dict), "/", len(block)
    
    if not any(data_dict):
        print "no data"
    else:
        X = []
        z = set()
        for v in data_dict.values():
            X.append(np.array(v["data"]))
            z.add(v["label"])
        #y = len(X)
        X = np.vstack(X)

        print "total faces:", X.shape[0]
        print "total pixels per face:", X.shape[1]
        print "total labels:", len(z)
        total_images = X.shape[0]
        # PCA
        k = len(z)
        print "principal component no: ", k
        pca_m = PCA(n_components=k).fit(X)

        # build projection within data_dict
        for ky in data_dict.keys():
            if "proj_pca" not in data_dict[ky]:
                data_dict[ky]["proj_pca"] = pca_m.transform(np.array(data_dict[ky]["data"]).reshape(1, -1))
   
    # update block and dict
    block.update(data_dict)
    data_dict.update(block)

    # save it
    with open('block.blk', 'wb') as f:
        cPickle.dump(block, f)
        print "block", len(block)


def main():
    initPCA()

    check = peer.config.nodes.find("nodes", "all")
    if not check:
        pn.updateNodes()
    if peer.config.relay:
        print "pNode started as a relay node."
        thread.start_new_thread(pn.normal, ())
        thread.start_new_thread(pn.relay, ())
        #pn.relay()
    else:
        print "pNode started as a normal node."
        #pn.normal()
        thread.start_new_thread(pn.normal, ())

    if not os.path.exists("data"):
        os.makedirs("data")
    
    settings = dict(
        template_path=os.path.join(os.path.dirname(__file__), "templates"),
        static_path=os.path.join(os.path.dirname(__file__), "static"),
        debug=False,
        autoescape=None)
    
    #tornado.options.parse_command_line()
    application = tornado.web.Application([
        (r"/", IndexPageHandler),
        (r"/login", LoginPageHandler),
        (r"/new", NewLabelPageHandler),
        (r"/cap", CapturePageHandler),
        #(r"/how", HowToPageHandler),
        (r"/done", DonePageHandler),
        (r"/logged", DoneLoginPageHandler),
        (r"/ws", WSocketHandler),
        (r"/train", TrainingSetHandler),
        (r"/train/(.*)", TrainedLabelHandler),
        (r"/data/(.*)", tornado.web.StaticFileHandler, {"path": "data"}),
    ], **settings)
    http_server = tornado.httpserver.HTTPServer(application)
    http_server.listen(port)
    print "server running at http://%s:%d/" % (ip, port)

    #import webbrowser
    #webbrowser.get("open -a /Applications/Google\ Chrome.app %s").open(
        # "http://%s:%d" % (ip, port))  ## mac only

    tornado.ioloop.IOLoop.instance().start()

if __name__ == "__main__":
    main()