#!/bin/bash

# If we are this host, we will configure special bouncer-specific settings:
# This is now disabled.
BOUNCER_HOST='disabled'


# 1. Fetch any dependencies
# we should have everything in the virtualenv? Or do we need to also get some
# system libraries? libyaml, anyone?
source /etc/mlab/slice-functions

set -e

# 2. Generate a ssl certificate
generate_ssl_certificate() {
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
}
# Currently disabled as it's not a supported mlab test.
# generate_ssl_certificate

# get the UID and GID to drop privileges to
# XXX This is currently disabled because of 
# https://trac.torproject.org/projects/tor/ticket/13116
# OONIB_UID=`id -u $SLICENAME`
# OONIB_GID=`id -g $SLICENAME`
OONIB_UID="null"
OONIB_GID="null"

# Set a sane umask
UMASK=0022

# randomly select either a tcp backend helper or a http backend helper to
# listen on port 80. Otherwise, bind to port 81
coin=$[$RANDOM % 2]
if [[ $coin > 0 ]]; then
  TCP_ECHO_PORT=80
  HTTP_ECHO_PORT=81
else
  TCP_ECHO_PORT=81
  HTTP_ECHO_PORT=80
fi

# NOTE: create a directory for raw ooni reports before archiving.
ARCHIVE_DIR=$SLICERSYNCDIR
REPORT_DIR=/var/spool/raw_reports
DATA_DIR=$SLICEHOME/data
TOR_DIR=$DATA_DIR/tor
INPUT_DIR=$DATA_DIR/inputs
DECK_DIR=$DATA_DIR/decks

sudo mkdir -p $REPORT_DIR
sudo mkdir -p $ARCHIVE_DIR
mkdir -p $TOR_DIR
mkdir -p $INPUT_DIR
mkdir -p $DECK_DIR

sudo chown $SLICENAME:slices $REPORT_DIR
sudo chown $SLICENAME:slices $ARCHIVE_DIR
sudo chown -R $SLICENAME:slices $DATA_DIR

# Tor will run as root for the moment
sudo chown -R root $TOR_DIR

# drop a policy.yaml in $DATA_DIR
echo "
nettest:
- {name: http_header_field_manipulation, version: 0.1.3}
- {name: http_header_field_manipulation, version: 0.1.4}
- {name: http_header_field_manipulation, version: 0.1.5}
" > $DATA_DIR/policy.yaml
sudo chown $SLICENAME:slices $DATA_DIR/policy.yaml

BOUNCER_FILE='null'

if [ `hostname` = "$BOUNCER_HOST" ]; then
    # Enable the bouncer:
    BOUNCER_FILE="$DATA_DIR/bouncer.yaml"

    # And update the bouncer config from cron on an hourly schedule:
    sudo ln -s /home/mlab_ooni/bin/update-bouncer.sh /etc/cron.hourly/50_update_ooni_bouncer_from_mlab_ns.sh
fi


# drop a config in $SLICEHOME
echo "
main:
    report_dir: '$REPORT_DIR'
    archive_dir: '$ARCHIVE_DIR'
    input_dir: '$INPUT_DIR'
    deck_dir: '$DECK_DIR'

    policy_file: '$DATA_DIR/policy.yaml'
    bouncer_file: $BOUNCER_FILE

    tor_datadir: '$TOR_DIR'
    tor_binary: '$SLICEHOME/bin/tor'
    tor2webmode: true
    tor_hidden_service: true

    database_uri: 'sqlite://$SLICEHOME/oonib_test_db.db'
    db_threadpool_size: 10

    logfile: '$SLICEHOME/oonib.log'
    pidfile: '$SLICEHOME/oonib.pid'
    nodaemon: false
    originalname: null
    chroot: null
    rundir: '$SLICEHOME'
    umask: '$UMASK'
    euid: null
    uid: $OONIB_UID
    gid: $OONIB_GID
    socks_port: 9055
    uuid: null
    no_save: true
    profile: null
    debug: false
    stale_time: 3600

    report_file_template: '{year}/{month}/{day}/{year}{month}{day}T{hour}:{minute}:{second}-{probe_cc}-{test_name}-{iso8601_timestamp}-{probe_asn}-probe.{ext}'

helpers:
    http-return-json-headers:
        address: null
        port: $HTTP_ECHO_PORT
        server_version: Apache

    tcp-echo:
        address: null
        port: $TCP_ECHO_PORT

    daphn3:
        yaml_file: null
        pcap_file: null
        port: null

    dns:
        address: null
        udp_port: null
        tcp_port: null
    
    dns_discovery:
        address: null
        udp_port: null
        tcp_port: null
        resolver_address: null

    ssl:
        address: null
        private_key: null
        certificate: null
        port: null" > $SLICEHOME/oonib.conf

sudo chown $SLICENAME:slices $SLICEHOME/oonib.conf
