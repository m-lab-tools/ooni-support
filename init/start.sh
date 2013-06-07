#!/bin/sh

source /etc/mlab/slice-functions
cd $SLICEHOME
# NOTE: oonib drops privilges if UID/GID are set in oonib.conf
$SLICEHOME/bin/oonib -c $SLICEHOME/oonib.conf &
