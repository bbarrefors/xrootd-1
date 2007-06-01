#!/bin/bash
#################################################################
## simple test for xrootd build testing
##
## 
## Initial version: 31.5.2007
## by Derek Feichtinger <derek.feichtinger@cern.ch>
##
## Version info: $Id$
## Checked in by $Author$
################################################################################

#############################
# Bootstrap

# srcdir is passed as environment variable by "make check"
if test x"$srcdir" != x; then
    cd $srcdir/test
fi

curdir=`pwd`
if test ! -r testconfig.sh; then
    echo "Error: Cannot find configuration file testconfig.sh (pwd: $curdir)" >&2
    exit 1
fi

. testconfig.sh

if test ! -e $top_srcdir/src/XrdOfs/XrdOfs.hh; then
    echo "Error: $top_srcdir seems not to be the correct top_srcdir" >&2
    exit 1
fi

top_srcdir=$(cd $top_srcdir;pwd)
top_builddir=$(cd $top_builddir;pwd)

##################################################################
# CONFIGURATION SETTINGS

testdir=$top_srcdir/test
workdir=$top_builddir/test/work
exportdir=$workdir/exportdir

logfile=$workdir/test1-xrootd.log
xrdport=22000
##################################################################

cleanup() {
    if test 0"$1" -lt 2; then
	echo "Error: cleanup() no valid PID given: $1"
	exit 1
    fi
    kill $1 &>/dev/null
    status=$?
    if test 0"$status" -ne 0; then
	echo "Error: Failed to kill process ($PID)" >&2
	return 1
    fi
    return 0
}



cd $testdir
mkdir -p $exportdir
cp $testdir/test1.sh $exportdir/testfile_r

# Create simple xrootd config file
echo "writing $workdir/test1-xrootd.cfg"
cat <<EOF > $workdir/test1-xrootd.cfg
xrootd.export $exportdir
xrd.port $xrdport
EOF

# start up xrootd
rm -rf $logfile
echo -n "Starting up a test xrootd (port $xrdport)..."
$top_builddir/src/XrdXrootd/xrootd -c $workdir/test1-xrootd.cfg -l $logfile &
PID=$!

if test 0"$PID" -eq 0; then
    echo "[FAILED]"
    echo "Error: Failed to get process ID of xrootd" >&2
    exit 1
fi

sleep 1

kill -0 $PID
status=$?
if test 0"$status" -ne 0; then
    echo "[FAILED]"
    echo "Error: Failed to start up test xrootd. Look at $logfile" >&2
    exit 1
fi
echo "[OK]"

# read a file
echo -n "Reading a file from xrootd..."
rm -f $workdir/testfile_r
$top_builddir/src/XrdClient/xrdcp -s root://localhost:$xrdport/$exportdir/testfile_r $workdir/testfile_r
if test ! -f $workdir/testfile_r; then
    echo "[FAILED]"
    cleanup $PID
    exit 1
fi
echo "[OK]"

# write a file
echo -n "Writing a file to xrootd..."
rm -f $exportdir/testfile_w
$top_builddir/src/XrdClient/xrdcp -s $workdir/testfile_r root://localhost:$xrdport/$exportdir/testfile_w
if test ! -f $exportdir/testfile_w; then
    echo "[FAILED]"
    cleanup $PID
    exit 1
fi
echo "[OK]"


# kill the xrootd process
echo -n "Shutting down the test xrootd..."
cleanup $PID
status=$?
#echo STATUS is $status
if test 0"$status" -ne 0; then
    echo "[FAILED]"
    echo "Error: Failed to kill process ($PID)" >&2
    return 1
fi
echo "[OK]"

# clean up the work area
echo -n "Cleaning up work area..."
files="$exportdir/testfile_r 
$exportdir/testfile_w
$workdir/testfile_r
$workdir/test1-xrootd.cfg
$workdir/test1-xrootd.log"

rm -rf $files
rmdir $exportdir
rmdir $workdir
status=$?
#echo STATUS is $status
if test 0"$status" -ne 0; then
    echo "[FAILED]"
    echo "Error: Failed to kill process ($PID)" >&2
    return 1
fi
echo "[OK]"

exit 0



