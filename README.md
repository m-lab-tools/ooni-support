M-Lab Deployment Process
=========================

This document describes the process of deploying
Ooni on M-Lab. It assumes the steps in the [Ooni Release
Procedure](https://github.com/TheTorProject/ooni-spec/blob/master/Release-Procedure.md)
document have been completed by the Ooni team.

More details about M-Lab development and deployment procedures, not specific to
Ooni, are in the [m-lab-tools package repository
README](https://github.com/m-lab-tools/package).

What's Required
----------------

This is a checklist of all the things that are necessary for the deployment.
Ensure that you have them all before starting.

### For RPM Building

- Git: `yum install git`
- SVN: `yum install svn`
- rpm-build: `yum install rpm-build`
- m4: `yum install m4`
- Read access to the [`ooni-support` repository on
  GitHub](https://github.com/m-lab-tools/ooni-support).

### For Ooni Installation

- The Ooni `.rpm` file (See the "Building the Ooni RPM" section below).

Building the Ooni RPM
----------------------

Follow these steps to build the Ooni RPM.

1. First, create a temporary directory *outside* of `/home/mlab_ooni` and clone
   `ooni-support` there: 

        cd /tmp/
        git clone --recursive https://github.com/m-lab-tools/ooni-support.git
   
2. Change directories into the `ooni-support` clone.
3. Run `git checkout <tag>` where `<tag>` is the tag you want to build.
4. Ensure that it is OK to delete everything in `/home/mlab_ooni`. Create
   a backup just in case.
5. Run `./package/slicebuild.sh mlab_ooni`.

**WARNING:** The last step will remove *everything* in `/home/mlab_ooni`.

**NOTE:** The `ooni-support` clone MUST be outside of `/home/mlab_ooni`,
otherwise, otherwise an `rsync` copy will go into an infinite loop because of
the destination directory being inside the source directory.

This will create an `mlab_ooni-XYZ.rpm` file (where `XYZ` is the version number
and architecture name) in `ooni-support/build/slicebase-i386/i686/`.

Installing the RPM
-------------------

With the `mlab_ooni-XYZ.rpm` (where `XYZ` is a placeholder for the version and
architecture of the build) file, run the following commands:

    sudo yum install openssl
    sudo yum install yum-cron
    sudo rpm -Uvh mlab_ooni-XYZ.rpm

This installs the Ooni backend software on the slice. Next, initialize the Ooni
configuration.

Initializing the Ooni Configuration
------------------------------------

To initialize the Ooni configuration, change directories into
`/home/mlab_ooni/init`, which was created by installing the `.rpm`, then run the
following commands:

    ./initialize.sh

This will create the Ooni configuration. Ooni is now ready to be started.

**Note:** You don't have to run `initialize.sh` as root, but it does use sudo
internally, so whichever user you run it as needs to have `sudo` privileges.

Starting and Stopping Ooni
---------------------------

To start and stop the Ooni backend service, change directories into the `init`
subdirectory of the `ooni-support` repository and run `sudo ./start.sh` and
`sudo ./stop.sh` respectively.

Testing
--------

After deployment, tests should be performed to ensure Ooni is working properly.
These tests are out of scope of this document.
