#!/bin/sh
source /etc/mlab/slice-functions
cd $SLICEHOME
if test -f $SLICEHOME/oonib.pid ; then
    kill `cat $SLICEHOME/oonib.pid`
fi

