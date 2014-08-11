#!/bin/bash
source /etc/mlab/slice-functions
if test -f $SLICEHOME/mlabsim.pid ; then
    kill `cat $SLICEHOME/mlabsim.pid`
    rm "$SLICEHOME/mlabsim.pid"
fi
