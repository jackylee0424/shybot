

## TODO
# 1. batch create testing nodes
# 2. verify/visualize batch nodes
# 3. turn block into blockchain with Merkle hash

# credit:
# zcoin, https://github.com/Max00355/zCoin
# merkle, http://www.righto.com/2014/02/bitcoin-mining-hard-way-algorithms.html


import os
# for beta testing, remove *.blk, *.pyc, and *.db
for i in["block.blk", "nodes.db", "nodes.lock"]:
    if os.path.exists(i):
        os.remove(i)
from os.path import join
import config  # config parameters
import socket
import random
import thread
import json
import time
import hashlib
import cPickle
import pickle
import logging

node_sleep_time = config.sleep_time
node_label = config.label


def merkle(hashList):
    ## <merkle hashing from Ken Shirriff>
    if len(hashList) == 1:
        return hashList[0]
    newHashList = []
    # Process pairs. For odd length, the last is skipped
    for i in range(0, len(hashList) - 1, 2):
        newHashList.append(hash2(hashList[i], hashList[i + 1]))
    if len(hashList) % 2 == 1:  # odd, hash last item twice
        newHashList.append(hash2(hashList[-1], hashList[-1]))
    return merkle(newHashList)


def hash2(a, b):
    ## <merkle hashing from Ken Shirriff>
    # Reverse inputs before and after hashing
    # due to big-endian / little-endian nonsense
    a1 = a.decode('hex')[::-1]
    b1 = b.decode('hex')[::-1]
    h = hashlib.sha256(hashlib.sha256(a1 + b1).digest()).digest()
    return h[::-1].encode('hex')


def count_send():
    mine = config.nodes.find("nodes", "all")
    if not mine:
        mine = 0
    else:
        mine = len(mine)
    check = send_command({"cmd": "get_nodes_count"}, out=True)
    if not check:
        return
    check = json.loads(check)
    if check['nodes'] > mine:
        send_nodes()


def count_nodes(obj, data):
    co = config.nodes.find("nodes", "all")
    if not co:
        co = 0
    else:
        co = len(co)
    obj.send(json.dumps({"nodes": co}))


def get_nodes(obj, data):
    with open("nodes.db", 'rb') as file:
        while True:
            data = file.read(100)
            if not data:
                break
            obj.send(data)


def send_nodes(god=False):
    if god:
        nodes = config.seeds
    else:
        nodes = config.nodes.find("nodes", {"relay": 1})
        random.shuffle(nodes)
    for x in nodes:
        s = socket.socket()
        try:
            s.connect((x['ip'], x['port']))
        except:
            s.close()
            continue
        else:
            s.send(json.dumps({"cmd": "get_nodes"}))
            out = ""
            while True:
                data = s.recv(1024)
                if not data:
                    break
                out = out + data
            while os.path.exists("nodes.lock"):
                time.sleep(0.1)
            open("nodes.lock", 'w').close()
            with open("nodes.db", 'wb') as file:
                file.write(out)
            os.remove("nodes.lock")
            break


def register(obj, data):
    ''' TODO: update to latest node characteristics '''
    while os.path.exists("nodes.lock"):
        time.sleep(0.1)
    open("nodes.lock", 'w').close()
    allnodes = config.nodes.find("nodes", "all")
    tmp = set()
    for i in allnodes:
        tmp.add(i['ip'] + ":" + str(i['port']))
    if data['ip'] + ":" + str(data['port']) not in tmp:
        config.nodes.insert("nodes", data)
        config.nodes.save()
    else:
        stuff = config.nodes.find(
            "nodes",
            {"port": data['port'], "ip": data['ip']})
        if stuff:
            for x in stuff:
                config.nodes.remove("nodes", x)
                config.nodes.save()
            config.nodes.insert("nodes", data)
            config.nodes.save()
    os.remove("nodes.lock")


def send_command(cmd, out=False, god=False):
    if god:
        nodes = config.seeds
    else:
        nodes = config.nodes.find("nodes", {"relay": 1})
        if nodes:
            random.shuffle(nodes)
    if not nodes:
        nodes = config.seeds
    for x in nodes:
        s = socket.socket()
        try:
            s.connect((x['ip'], x['port']))
        except:
            s.close()
            continue
        else:
            s.send(json.dumps(cmd))
            out = ""
            while True:
                data = s.recv(1024)
                if not data:
                    break
                out = out + data
            s.close()
            if out:
                return out

## basic function
# - automatically send out latest dataset to peers
# - block = dict(hash=dict(filename=label, base64=image_content))


def sha256_for_file(path, block_size=256 * 128):
    cipher = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(block_size), b''):
            cipher.update(chunk)
    return cipher.hexdigest()


class Node:
    def __init__(self):
        self.data_dict = dict()
        self.label_dict = dict()
        self.cmds = {
            "get_nodes": get_nodes,
            "register": register,
            "get_nodes_count": count_nodes,
            "sync": self.syncfile,
        }
        self.block = dict()
        self.merkle_hash = ""
        self.allnodes = ""
        self.node_ip = config.host
        self.node_port = config.port

    def generate_merkle(self):
        self.merkle_hash = merkle(sorted(self.data_dict.keys()))

    def send_register(self):
        send_command({
            "cmd": "register",
            "relay": config.relay,
            "public": "hello from %s node" % node_label,
            "port": config.port,
            "ip": config.host,
            "node_label": node_label,
            "merkle_hash": self.merkle_hash,
            "block_size": len(self.block["data_dict"]) if "data_dict" in self.block else 0,
        })

    def parsePNG(self, pngfile):
        if pngfile[-3:] != "png":
            return 0
        with open(pngfile, "rb") as f:
            ib64 = f.read()
            return ib64.encode("base64").strip()

    def syncfile(self, obj, data):
        ## randomly send out one element in data_dict
        if self.data_dict.keys():
            r = random.choice(self.data_dict.keys())
            obj.send(json.dumps(dict(
                cmd="sync", note="syncing from %s" % node_label, hash=r,
                data=self.data_dict[r]["data"],
                label=self.data_dict[r]["label"],
                labeldict=self.label_dict,
                ts=self.data_dict[r]["ts"])))
        else:
            ## no return hash
            obj.send(json.dumps(dict(
                cmd="sync", note="syncing from %s" % node_label,
                ts=time.time())))

    def updateNodes(self):
        #send_nodes(True)
        check = config.nodes.find("nodes", "all")
        self.allnodes = check
        if not check:
            ip = config.host
            config.nodes.insert("nodes", {
                "ip": ip,
                "relay": config.relay,
                "port": config.port,
                "merkle_hash": self.merkle_hash,
                "block_size": len(self.block["data_dict"]) if "data_dict" in self.block else 0,
                "node_label": node_label,
            })
            config.nodes.save()
        self.send_register()

    def relay(self):
        #send_nodes()
        self.send_register()
        sock = socket.socket()
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((config.host, config.port))
        sock.listen(5)
        while True:
            obj, conn = sock.accept()
            thread.start_new_thread(self.handle, (obj, conn[0]))

    def handle(self, obj, ip):
        data = obj.recv(10240)
        if data:
            try:
                data = json.loads(data)
            except:
                obj.close()
                return
            else:
                if "cmd" in data:
                    if data['cmd'] in self.cmds:
                        data['ip'] = ip
                        self.cmds[data['cmd']](obj, data)
                        obj.close()

    def normal(self):
        counter = 0
        if not config.relay:
            logging.debug("send register")
            self.send_register()
        while True:
            #count_send()
            ## sending sync command to peers and load responses
            try:
                sync_data = json.loads(send_command({"cmd": "sync"}))
            except:
                logging.error("error in receiving")
                sync_data = dict()

            # check if received message is valid (contain a hash)
            if "hash" in sync_data:

                # load sync-ed meta labels
                if "labeldict" in sync_data:
                    if os.path.exists(join('data', 'labels.bin')):
                        with open(join('data', 'labels.bin'), 'rb') as input:
                            self.label_dict.update(pickle.load(input))
                    self.label_dict.update(sync_data["labeldict"])
                    with open(join('data', 'labels.bin'), 'wb') as output:
                        pickle.dump(
                            self.label_dict, output, pickle.HIGHEST_PROTOCOL)

                # load block
                if os.path.exists("block.blk"):
                    with open('block.blk', 'rb') as f:
                        self.block = cPickle.load(f)
                        self.data_dict.update(self.block["data_dict"])
                else:
                    # create a blank block
                    with open('block.blk', 'wb') as f:
                        cPickle.dump(self.block, f)
                        logging.debug("empty block created")

                # update block and dict
                if "data_dict" not in self.block:
                    self.block["data_dict"] = dict()

                # check duplicated hash (can do more stuff here)
                if sync_data["hash"] not in self.block["data_dict"]:

                    # add new hash to block
                    self.block["data_dict"][sync_data["hash"]] = sync_data

                    # calculate merkle hash
                    if any(self.data_dict.keys()):
                        self.merkle_hash = merkle(
                            sorted(self.data_dict.keys()))

                    # save it
                    with open('block.blk', 'wb') as f:
                        cPickle.dump(self.block, f)
                        logging.info(
                            "block %d %s",
                            len(self.block["data_dict"]), self.merkle_hash)
            # sleep
            logging.info("sleep for %d sec", node_sleep_time)
            time.sleep(node_sleep_time)
            if counter % 5 == 0:
                self.updateNodes()
            counter += 1

if __name__ == "__main__":

    if not os.path.exists("data"):
        os.makedirs("data")

    logging.basicConfig(
        format='[%(asctime)s] %(name)s %(levelname)s %(message)s',
        level=logging.DEBUG)
    logger = logging.getLogger(__name__)

    pn = Node()
    #check = config.nodes.find("nodes", "all")
    #if not check:
    #    pn.updateNodes()
    if config.relay:
        logging.info("pNode started as a relay node.")
        thread.start_new_thread(pn.normal, ())
        pn.relay()
    else:
        logging.info("pNode started as a normal node.")
        pn.normal()
