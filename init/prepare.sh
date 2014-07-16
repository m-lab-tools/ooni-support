#!/bin/bash

# Warning
# We advise installing virtualenv-1.9 or greater. Prior to version 1.9, the pip
# included in virtualenv did not not download from PyPI over SSL.
# Solution, use virtualenv-1.9
# XXX: where is a signed release for any of virtualenv?

# XXX
# Retrieved from http://www.virtualenv.org/en/1.9.X/news.html Mar 6 2013
# Warning
# Python bugfix releases 2.6.8, 2.7.3, 3.1.5 and 3.2.3 include a change that will
# cause “import random” to fail with “cannot import name urandom” on any
# virtualenv created on a Unix host with an earlier release of Python
# 2.6/2.7/3.1/3.2, if the underlying system Python is upgraded. This is due to
# the fact that a virtualenv uses the system Python’s standard library but
# contains its own copy of the Python interpreter, so an upgrade to the system
# Python results in a mismatch between the version of the Python interpreter and
# the version of the standard library. It can be fixed by removing
# $ENV/bin/python and re-running virtualenv on the same target directory with the
# upgraded Python.

# In the wild:
# http://stackoverflow.com/questions/10366821/python-importerror-cannot-import-urandom-since-ubuntu-12-04-upgrade

# Solution: Redeploy oonib after upgrading python 2.6.6 to 2.6.8

set -x 
set -e

if [ -z "$SOURCE_DIR" ] ; then
    echo "Expected SOURCE_DIR in environment"
    exit 1
fi
if [ -z "$BUILD_DIR" ] ; then
    echo "Expected BUILD_DIR in environment"
    exit 1
fi

if test -d $BUILD_DIR ; then
    rm -rf $BUILD_DIR/*
fi


OONIB_GIT_REPO=ooni-backend
VIRTUALENV_GIT_REPO=virtualenv

echo Installing build tools
sudo yum groupinstall -y Development\ Tools

echo Installing openssl-devel
sudo yum install -y openssl-devel

echo Installing glibc-static
sudo yum install -y glibc-static

echo Installing python-devel
sudo yum install -y python-devel

echo Installing sqlite-devel
sudo yum install -y sqlite-devel

echo Installing libffi-devel
sudo yum install -y libffi-devel

OONIB_PATH=$SOURCE_DIR/$OONIB_GIT_REPO
VIRTUALENV_PATH=$SOURCE_DIR/$VIRTUALENV_GIT_REPO
  
# See warning. Remove python and redeploy virtualenv with current python
PYTHON_EXE=$BUILD_DIR/bin/python
if [ -e $PYTHON_EXE ] ; then
  rm $PYTHON_EXE
fi
python $VIRTUALENV_PATH/virtualenv.py --no-site-packages $BUILD_DIR
if [ ! -e $PYTHON_EXE ] ; then
  exit 1
fi

# run setup.py and fetch dependencies
cd $OONIB_PATH
pip install -r requirements.txt --use-mirrors
# From the Ooni README: Note: it is important that you install the requirements
# before you run the setup.py script. If you fail to do so they will be
# downloaded over plaintext.
$PYTHON_EXE setup.py install

# build a static tor
mkdir -p $BUILD_DIR/
cd $BUILD_DIR
$OONIB_PATH/scripts/build_tor2web_tor.sh

# add to bin
if [ -e $BUILD_DIR/tor ]; then
  cp $BUILD_DIR/tor $BUILD_DIR/bin/
else
  echo "Error: missing tor binary"
  exit 1
fi

# drop the init scripts into $BUILD_DIR
cp -r $SOURCE_DIR/init $BUILD_DIR
rsync -ar --exclude .git $OONIB_PATH $BUILD_DIR/

# remove pre-compiled .py files
find $BUILD_DIR -name "*.pyc" -a -exec rm -f {} \;

# NOTE: keep only: bin lib init $OONIB_GIT_REPO
rm -rf $BUILD_DIR/include
rm -rf $BUILD_DIR/libevent-*
rm -rf $BUILD_DIR/tor*
rm -rf $BUILD_DIR/openssl-*
rm -rf $BUILD_DIR/zlib-*
rm -rf $BUILD_DIR/build

