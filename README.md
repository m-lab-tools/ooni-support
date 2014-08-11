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

If the slice's hostname matches the `BOUNCER_HOST` defined in `initialize.sh`,
then a cron job for updating the bouncer configuration from the mlab-ns
simulator will be added to `/etc/cron.hourly`. To temporarily or permanently
disable the cron job, edit
`/etc/cron.hourly/50_update_ooni_bouncer_from_mlab_ns.sh` and change `ENABLED`
to `false`.

The bouncer is not automatically enabled, only the cron job to generate the
`bouncer.yaml` configuration file is. If you want to run a bouncer, you have to
manually edit the configuration.

Starting and Stopping Ooni
---------------------------

To start and stop the Ooni backend service, change directories into the `init`
subdirectory of the `ooni-support` repository and run `sudo ./start.sh` and
`sudo ./stop.sh` respectively.

If you would like to start the `mlab-ns` simulator, run `sudo
./start-mlabsim.sh`, and the simulator will start if the slice's hostname
matches the `MLABSIM_HOME` defined in `start-mlabsim.sh`. Run `sudo
./stop-mlabsim.sh` to stop the simulator.

Testing
--------

After deployment, integration tests should be performed to ensure the
full Ooni stack and mlab-ns integration are working properly.

The end goal is to run ooniprobe against the deployment and verify that
a report is collected. The specific steps are as follows:

### 1. Deploy the Ooni Slice

This is documented above.


### 2. Start the Ooni stack and verify it is running and configured correctly.

1. SSH into a given Ooni sliver.
2. Run `ls -l /home/mlab_ooni/oonib.conf` to ensure this file exists.
3. Run `sudo /home/mlab_ooni/init/start.sh` to start oonib.
4. Run `sudo /home/mlab_ooni/init/start-mlabsim.sh` to start the `mlab-ns` simulator if this is the simulator home.
5. Run `ps aux | grep oonib` and verify there is a single oonib process. Make sure the first column, `UID` is *not* root. Here's an example output of a correct process listing:

    [mlab_ooni@mlab1 ~]$ ps aux | grep oonib
    543      26510  0.0  0.1  41140 22840 ?        SNl  Aug05   0:00 /home/mlab_ooni/bin/python /home/mlab_ooni/bin/oonib -c /home/mlab_ooni/oonib.conf
    543      27256  0.0  0.0   2280   560 ?        S+   Aug05   0:00 grep oonib

6. Examine the `oonib` log to verify HTTP test\_helper, the collector, and optionally the bouncer are running, and there are no errors.

Here are some example lines for the started services:

    2014-08-06 22:01:03+0000 Starting factory <oonib.testhelpers.http_helpers.HTTPReturnJSONHeadersHelper instance at 0x9375e0c>
    2014-08-06 22:01:06+0000 Exposed collector Tor hidden service on httpo://fooblah.onion
    2014-08-06 22:01:06+0000 Exposed bouncer Tor hidden service on httpo://examplebouncer.onion

Note: The bouncer only runs on a single host which is defined in `BOUNCER_HOST` in `/home/mlab_ooni/init/initialize.sh`. If this log is on the bouncer host, remember to save the bouncer `.onion` for the Step 6 below.

Also, check the log file and verify that there are no errors or exceptions.


### 3. Verify that a single bouncer is running on the appropriate sliver.

If this is the bouncer host, after verifying that the bouncer is enabled in the `oonib.log` as above, also verify that the mlab-ns integration cron script is installed:

    [mlab_ooni@mlab1 ~]$ ls -l /etc/cron.hourly/50_update_ooni_bouncer_from_mlab_ns.sh
    lrwxrwxrwx 1 root root 37 Jul 30 21:48 /etc/cron.hourly/50_update_ooni_bouncer_from_mlab_ns.sh -> /home/mlab_ooni/bin/update-bouncer.sh


### 4. Verify mlab-ns integration is working.

#### 4a. Verify the mlab-ns-simulator is (or is not) running.

Note: This will change as mlab-ns integration is developed. Currently the deployment relies on a simulator, so these instructions are specific to the simulator.

The mlab-ns-simulator only runs on a single host, defined by `MLABSIM_HOME` in `BOUNCER_HOST` in `/home/mlab_ooni/init/start-mlabsim.sh`. After all of the prior steps, on this particular host you should also verify that `mlabsim` is running:

    [mlab_ooni@mlab1 ~]$ ps aux | grep mlabsim
    root     26482  0.0  0.1  26916 21904 ?        SN   Aug05   0:01 /home/mlab_ooni/bin/python /home/mlab_ooni/bin/mlabsim --log-level DEBUG
    543      28177  0.0  0.0   2280   560 ?        S+   Aug05   0:00 grep mlabsim

If this host is not `MLABSIM_HOME`, then verify that the `mlab-ns` simulator is
*not* running.

#### 4b. Manually run getconfig.py

Note: This may be specific to the simulator deployment and may change when nagios integration is complete.

On any sliver, run `/home/mlab_ooni/bin/getconfig.py`. Also, save the IP address of this slivver for the next step, which comes from running `get_ipv4.sh`.

Now verify that the above sliver's information appears in the simulator. Log into the simulator host and run:

    curl -sv 'http://127.0.0.1:8585/ooni?match=all'

Verify that the output includes an entry with a `"tool_extra"` section that contains the collector `.onion` and `http-return-json-headers` test helper URL with the IP address from above.


#### 4c. Manually run makeconfig.py

Now log into the bouncer host and run `sudo /etc/cron.hourly/50_update_ooni_bouncer_from_mlab_ns.sh` to update the bouncer.


### 5. Install ooniprobe on a local machine and configure it for the M-Lab deployment.

The instructions for installing ooni-probe:

https://github.com/TheTorProject/ooni-probe/blob/master/README.md#installation


### 6. Run ooniprobe with the M-Lab test deck.

Run the M-Lab test deck against the bouncer onion:

    ooniprobe -b httpo://examplebouncer.onion -i ooni-probe/data/decks/mlab.deck

Note: Substitute the actual bouncer `.onion` gathered in Step 2.


### 7. Verify that a report was collected on a collector.

Once a report is successfully closed it should appear under `/var/spool/mlab_ooni` within a country code directory, and its name has a timestamp.

If the report has not appeared there, check `/home/mlab_ooni/oonib.log` for outline lines such as these:

    2014-08-06 23:29:55+0000 [http] 200 POST /report (64.9.225.208) 242.97ms
    2014-08-06 23:29:58+0000 [http] 200 POST /report/2014-08-06T232955Z_AS0_g10EmWcTWQLunudXzAbyyD4DWEww31UfLFGHk2wCRRBKbBaizR/close (64.9.225.208) 15.60ms

If such lines are not present, review the `ooniprobe` output to verify it connected successfully to a collector.
