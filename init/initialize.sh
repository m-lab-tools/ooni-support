#!/bin/sh

# 1. Fetch any dependencies
# we should have everything in the virtualenv? Or do we need to also get some
# system libraries? libyaml, anyone?
# XXX: Can we get a newer version of libyaml from a fc-xx repo?

# 2. Generate a ssl certificate
cd $SCRIPT_ROOT
openssl genrsa -des3 -out private.key 4096
openssl req -new -key private.key -out server.csr
cp private.key private.key.org

# Remove passphrase from key
openssl rsa -in private.key.org -out private.key
openssl x509 -req -days 365 -in server.csr -signkey private.key -out certificate.crt
rm private.key.org

# 2. Set up any config files
# Lets have a look at our config
# a. set up the path to our tor binary
# b. got tor2webmode

# Set up our firewall rules
# XXX: Confirm that sudo will work with MLAB.
# Map port 80 to config.helpers.http_return_request.port  (default: 57001)
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 80 -j REDIRECT --to-ports 57001
# Map port 443 to config.helpers.ssl.port  (default: 57006)
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 443 -j REDIRECT --to-ports 57006
# Map port 53 udp to config.helpers.dns.udp_port (default: 57004)
sudo iptables -t nat -A PREROUTING -p tcp -m udp --dport 53 -j REDIRECT --to-ports 57004
# Map port 53 tcp to config.helpers.dns.tcp_port (default: 57005)
sudo iptables -t nat -A PREROUTING -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 57005


from oonib import Storage
import os

def get_root_path():
    this_directory = os.path.dirname(__file__)
    root = os.path.join(this_directory, '..')
    root = os.path.abspath(root)
    return root

backend_version = '0.0.1'

# XXX convert this to something that is a proper config file
main = Storage()

# This is the location where submitted reports get stored
main.report_dir = os.path.join(get_root_path(), 'oonib', 'reports')

# This is where tor will place it's Hidden Service hostname and Hidden service
# private key
main.tor_datadir = os.path.join(get_root_path(), 'oonib', 'data', 'tor')

main.database_uri = "sqlite:"+get_root_path()+"oonib_test_db.db"
main.db_threadpool_size = 10
#main.tor_binary = '/usr/sbin/tor'
main.tor_binary = '/usr/local/bin/tor'

# This requires compiling Tor with tor2web mode enabled
# BEWARE!! THIS PROVIDES NO ANONYMITY!!
# ONLY DO IT IF YOU KNOW WHAT YOU ARE DOING!!
# HOSTING A COLLECTOR WITH TOR2WEB MODE GIVES YOU NO ANONYMITY!!
main.tor2webmode = True

helpers = Storage()

helpers.http_return_request = Storage()
helpers.http_return_request.port = 57001
# XXX this actually needs to be the advertised Server HTTP header of our web
# server
helpers.http_return_request.server_version = "Apache"

helpers.tcp_echo = Storage()
helpers.tcp_echo.port = 57002

helpers.daphn3 = Storage()
#helpers.daphn3.yaml_file = "/path/to/data/oonib/daphn3.yaml"
#helpers.daphn3.pcap_file = "/path/to/data/server.pcap"
helpers.daphn3.port = 57003

helpers.dns = Storage()
helpers.dns.udp_port = 57004
helpers.dns.tcp_port = 57005

helpers.ssl = Storage()
#helpers.ssl.private_key = /path/to/data/private.key
#helpers.ssl.certificate = /path/to/data/certificate.crt
#helpers.ssl.port = 57006



