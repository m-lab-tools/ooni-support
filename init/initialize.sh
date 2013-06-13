#!/bin/bash

# 1. Fetch any dependencies
# we should have everything in the virtualenv? Or do we need to also get some
# system libraries? libyaml, anyone?
source /etc/mlab/slice-functions

set -e

# TODO: remove this is nothing breaks. 
#yum install -y PyYAML python-ipaddr

# 2. Generate a ssl certificate
cd $SLICEHOME

#XXX: we should think about setting these fields more carefully
OPENSSL_SUBJECT="/C=US/ST=CA/CN="`hostname`
OPENSSL_PASS=file:$SLICEHOME/cert.pass
sudo -u $SLICENAME dd if=/dev/random of=$SLICEHOME/cert.pass bs=32 count=1
sudo -u $SLICENAME openssl genrsa -des3 -passout $OPENSSL_PASS -out private.key 4096
sudo -u $SLICENAME openssl req -new -passin $OPENSSL_PASS -key private.key -out server.csr -subj $OPENSSL_SUBJECT
sudo -u $SLICENAME cp private.key private.key.org

# Remove passphrase from key
sudo -u $SLICENAME openssl rsa -passin file:$SLICEHOME/cert.pass -in private.key.org -out private.key
sudo -u $SLICENAME chmod 600 private.key
sudo -u $SLICENAME openssl x509 -req -days 365 -in server.csr -signkey private.key -out certificate.crt
rm private.key.org
rm cert.pass

# get the UID and GID to drop privileges to
OONIB_UID=`id -u $SLICENAME`
OONIB_GID=`id -g $SLICENAME`

# randomly select either a tcp backend helper or a http backend helper to
# listen on port 80. Otherwise, bind to port 81
coin=$[$RANDOM % 2]
if [[ $coin > 0 ]]; then
  TCP_ECHO_PORT=80
  HTTP_ECHO_PORT="Null"
else
  TCP_ECHO_PORT="Null"
  HTTP_ECHO_PORT=80
fi

# NOTE: create a directory for raw ooni reports before archiving.
ARCHIVE_DIR=$SLICERSYNCDIR
REPORT_DIR=/var/spool/raw_reports
mkdir -p $REPORT_DIR
chown $SLICENAME:slices $REPORT_DIR

# drop a config in $SLICEHOME
echo "
main:
    report_dir: '$REPORT_DIR'
    archive_dir: '$ARCHIVE_DIR'
    tor_datadir: 
    logfile: '$SLICEHOME/oonib.log'
    database_uri: 'sqlite://$SLICEHOME/oonib_test_db.db'
    db_threadpool_size: 10
    tor_binary: '$SLICEHOME/bin/tor'
    tor2webmode: true
    pidfile: '$SLICEHOME/oonib.pid'
    nodaemon: false
    originalname: Null
    chroot: Null
    rundir: .
    umask: Null
    euid: Null
    uid: $OONIB_UID
    gid: $OONIB_GID
    socks_port: 9055
    uuid: Null
    no_save: true
    profile: Null
    debug: Null
    stale_time: 3600

helpers:
    http_return_request:
        port: $HTTP_ECHO_PORT
        server_version: Apache

    tcp_echo:
        port: $TCP_ECHO_PORT

    daphn3:
        yaml_file: Null
        pcap_file: Null
        port: Null

    dns:
        udp_port: Null
        tcp_port: Null

    ssl:
        private_key: '$SLICEHOME/private.key'
        certificate: '$SLICEHOME/certificate.crt'
        port: 443" > $SLICEHOME/oonib.conf

chown $SLICENAME:slices $SLICEHOME/oonib.conf
