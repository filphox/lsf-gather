#!/bin/bash
#
# Description:	Simple script to gather basic LSF configuration information, copy it to a directory
#				and then compress that directory into a file to send to IBM Technical Services.
#
#				The script should be saved as lsf_gather.sh and set as executable. It can be run
#				from anywhere the user has write permission to create the configuration archive.
#
# Author: Phil Fox
# Date: 28-July-2022
# 
# 28-July-2022: Improved os-release file capture
# 11-Jan-2022: Initial version

# LSF Primary Administrator
LSFG_USER="lsfadmin"

# Name of folder & zip file to store info
LSFG_DIR="lsf-gather"

if [ "$USER" != "root" ]
then
    echo 'This script should be run as root'
    exit 1
fi

if [ ! -v LSF_ENVDIR ]
then
	echo 'The $LSF_ENVDIR environment variable is not set, please source your LSF profile'
	exit 1
fi 

if [ ! -d "$LSF_ENVDIR" ]
then
	echo "The configuration directory '$LSF_ENVDIR' does not exist, is your shared filesystem mounted?"
	exit 1
fi

if [ ! -f "$LSF_ENVDIR/lsf.conf" ]
then
	echo "The main LSF configuration file '$LSF_ENVDIR/lsf.conf' does not exist, is your shared filesystem mounted?"
	exit 1
fi

# Check for existence of LSF binaries
bin_ok=0
echo "Checking for binaries: lsload lsid lshosts bhosts bqueues runuser"
for binary in lsid lsload lshosts bhosts bqueues runuser
do
	which $binary > /dev/null 2>&1
	if [ $? -eq 1 ]
	then
		echo "LSF binary '$binary' not found!"
		bin_ok=1
	fi
done

if [ $bin_ok -eq 1 ]
then
	exit 1
fi

# Create directory to store the gathered data
echo "Creating directory to store gathered data"
if [ ! -d "$LSFG_DIR" ]
then
	mkdir "$LSFG_DIR"
	if [ $? -eq 1 ]
	then
		exit 1
	fi
fi

# Capture data from command output and copy the config directory
echo "Gathering data ..."
echo "Running lsid"
lsid > "$LSFG_DIR/lsid.txt"
echo "Running lsclusters"
lsclusters -w > "$LSFG_DIR/lsclusters.txt"
echo "Running lsload"
lsload -w > "$LSFG_DIR/lsload.txt"
echo "Running lshosts"
lshosts -w > "$LSFG_DIR/lshosts.txt"
echo "Running bhosts (as $LSFG_USER)"
runuser -u $LSFG_USER -- bhosts -w > "$LSFG_DIR/bhosts.txt"
echo "Running bqueues (as $LSFG_USER)"
runuser -u $LSFG_USER -- bqueues -w > "$LSFG_DIR/bqueues.txt"
echo "Capture RPM database"
rpm -qa | sort > "$LSFG_DIR/rpmqa.txt"
echo "Capture system information"
uname -a > "$LSFG_DIR/uname.txt"
for relfile in $(find /etc -maxdepth 1 -name *release -printf "%f ")
do
	cp /etc/$relfile "$LSFG_DIR/$relfile"
done
echo "Capture /etc/hosts"
cp /etc/hosts "$LSFG_DIR/hosts.txt"
echo "Capture /etc/sudoers"
cp /etc/sudoers "$LSFG_DIR/sudoers.txt"
if [ -f "/etc/lsf.sudoers" ]
then
	echo "Capture /etc/lsf.sudoers"
	cp /etc/lsf.sudoers "$LSFG_DIR/lsf.sudoers.txt"
fi

echo "Capture filesystem information"
df -h > "$LSFG_DIR/disk.txt"
cp /etc/exports "$LSFG_DIR/exports.txt"
cp /etc/fstab "$LSFG_DIR/fstab.txt"
lsblk > "$LSFG_DIR/lsblk.txt"
pvs -a > "$LSFG_DIR/pvs.txt"
lvs -a > "$LSFG_DIR/lvs.txt"
vgs -a > "$LSFG_DIR/vgs.txt"
fdisk -l > "$LSFG_DIR/fdisk.txt"

echo "Copying config dir $LSF_ENVDIR to $LSFG_DIR ..." 
cp -a $LSF_ENVDIR $LSFG_DIR/conf

echo "Copying LSF work dir"
cp -a $LSF_ENVDIR/../work $LSFG_DIR/work

ANSIBLE_DIR="/opt/ibm/lsf_installer/playbook"
if [ -d "$ANSIBLE_DIR" ]
then
	echo "Copying Ansible playbook dir"
	cp -a $ANSIBLE_DIR $LSFG_DIR/playbook
fi

echo "Compressing gathered data ..."
tar zcf $LSFG_DIR.tgz $LSFG_DIR

if [ $? -eq 0 ];
then
	echo -e "\nData has been gathered successfully, please email the file '$LSFG_DIR.tgz' to IBM. Thank you"
else
	echo "Error compressing gathered data"
fi
