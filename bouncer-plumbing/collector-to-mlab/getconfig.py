#!/usr/bin/env python

# This script collects the portion of the bouncer.yaml config file for the Ooni
# collector and test helpers running on an M-Lab slice. To use it, run `python
# getconfig.py`, and if all goes well, the configuration portion, encoded in
# JSON, will be printed to stdout. If something goes wrong, an error message
# will be printed to stdout, and the exit status will be non-zero. The script
# assumes the oonib.conf file is in /home/mlab_ooni/oonib.conf. If not, pass the
# path as the first command-line option.

import sys
import os
import yaml
import json
import subprocess

def get_bouncer_config_part(oonib_conf):
    try:
        # Open this slice's oonib.conf
        f = open(oonib_conf, "r")
        oonib_conf_contents = f.read()
        f.close()
        oonib_conf_parsed = yaml.safe_load(oonib_conf_contents)
    except IOError:
        return_failure("Couldn't read oonib.conf")

    try:
        # Read this slice's (collector) .onion address.
        tor_datadir = oonib_conf_parsed['main']['tor_datadir']
        tor_hostname_path = os.path.join(tor_datadir, 'collector', 'hostname')
        f = open(tor_hostname_path, "r")
        tor_onion_address = f.read().strip()
        f.close()
    except IOError:
        return_failure("Couldn't read Tor hostname file")
    except KeyError:
        return_failure("Oonib.conf is not valid or is missing information.")

    # Find this slice's IP address.
    slice_ipv4_address = get_ipv4_address()

    # List the running test helpers and their addresses.
    test_helpers = {}
    try:
        # For this first M-Lab deployment, we only support one test, which is
        # http-return-json-headers. In the future, this script should
        # automatically determine which helpers are running on a slice and
        # include exactly those. This is tracked in:
        # https://github.com/m-lab-tools/ooni-support/issues/55

        # Test helpers are disabled by setting the port to Null in the YAML,
        # which translates to None in Python.

        http_return_headers_port = oonib_conf_parsed['helpers']['http-return-json-headers']['port']
        if http_return_headers_port is not None:
            test_helpers['http-return-json-headers'] = 'http://' + slice_ipv4_address + ':' + str(http_return_headers_port)

        tcp_echo_port = oonib_conf_parsed['helpers']['tcp-echo']['port']
        if tcp_echo_port is not None:
            test_helpers['tcp-echo'] = slice_ipv4_address + ':' + str(tcp_echo_port)

        # FIXME: What about the UDP port?
        dns_tcp_port = oonib_conf_parsed['helpers']['dns']['tcp_port']
        if dns_tcp_port is not None:
            test_helpers['dns'] = slice_ipv4_address + ':' + str(dns_tcp_port)

        # FIXME: What about the 'address' field of the ssl helper?
        ssl_port = oonib_conf_parsed['helpers']['ssl']['port']
        if ssl_port is not None:
            test_helpers['ssl'] = "https://" + slice_ipv4_address + ':' + str(ssl_port)

        # FIXME: Add daphn3 test helper.

    except KeyError:
        return_failure("Oonib.conf is not valid or is missing information.")

    config_part = {
        'httpo://' + tor_onion_address: {
            'test-helper': test_helpers
        }
    }

    return config_part

def get_ipv4_address():
    output = subprocess.Popen(["/home/mlab_ooni/bin/get_ipv4.sh"], stdout=subprocess.PIPE).communicate()[0]
    return output.strip()

def return_failure(msg):
    print "ERROR: " + msg
    exit(1)

def print_config(oonib_conf):
    part = get_bouncer_config_part(oonib_conf)
    print json.dumps(part)

oonib_conf = '/home/mlab_ooni/oonib.conf'
if len(sys.argv) >= 2:
    oonib_conf = sys.argv[1]

print_config(oonib_conf)
