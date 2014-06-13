#
# change this file to config.py
#

import landerdb
import socket
import random

try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(("google.com", 80))
    local_ip = s.getsockname()[0]
    s.close()
except:
    local_ip = "127.0.0.1"


label = "peer%d" % int(random.random()*100)
sleep_time = 5

# master node needs to be a relay
relay = 1  # set this to zero to "not" relay to other nodes (aka leaf node).
seeds = [{"ip": "192.168.1.118", "port": 6565}]  # master has no seeds
version = "0.0.1"
host = local_ip
port = 6565
nodes = landerdb.Connect("nodes.db")

print "%s:%d" % (host, port)
