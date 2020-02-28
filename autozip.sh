#!/bin/bash

# autozip.sh v1.4
# By: Jacob S. Steward - Jacob.Steward@us.af.mil

# Syntax:  ./autozip.sh /path/to/pcaps [YYYYMMDD] [/path/to/logdir]
# Example: ./autozip.sh /srv/pcap/ 20180101 /srv/pcap/autozip.log.d/
# This script takes a pcap directory and a positive integer as arguments. And optionally a specific directory to store the logs.
# Source directory is expected to contain .pcap files
# The script will zip pcap files to the same directory and record metrics about them in the log directory.


# TODO
#
# Better input validation.
#
# Total size entire folder unzipped vs. zipped
# ratio ^
# 



################################################################################
################################## FLAG CHECK ##################################
################################################################################

# Provides help if no flags or flags -h or --help are used
if [ -z $1 ] || [ $1 == "-h" ] || [ $1 == "--help" ]; then
	echo
	echo "Syntax: ./autozip.sh /path/to/pcaps [YYYYMMDD] [/path/to/logdir]"
	echo
	echo "/path/to/pcaps   - Directory that the pcap files are stored in."
	echo "[YYYYMMDD]        - (Optional) Date to be zipped. Defaults to 3 days ago."
	echo "[/path/to/logdir] - (Optional) Path to save the log to. Defaults to /path/to/pcaps/autozip.log.d/"
	echo
	echo "Example: ./autozip.sh /srv/pcap 20180101 /srv/pcap/autozip.log.d"
	echo
	exit 1 # Quit script
fi

# Check for proper number of arguments
if [ $4 ]; then # if there are too many arguments
	echo; echo "Error! Too many arguments!"; echo
	echo "See help for more info (-h or --help)"; echo
	exit 1 # Quit script
fi



###############################################################################
################################## INITIALIZE  ################################
###############################################################################

# pcap directory
PCAPDIR=$1"/"

# Date to be zipped
DATETOZIP=$2
if [ -z $2 ]; then DATETOZIP=$(date --date "-3 days" +%Y%m%d); fi # if DATETOZIP is not specified, use default

# Location for the logs
LOGDIR=$3"/"
if [ -z $3 ]; then LOGDIR=$PCAPDIR/autozip.log.d/; fi # if LOGDIR is not specified, use default
mkdir $LOGDIR 2>/dev/null # Create LOGDIR. Do not report error if it already exists.
LOGFILE=$LOGDIR$DATETOZIP
touch $LOGFILE

# Temporary files
FILELIST="/tmp/oldpcaps"
PREZIPFILESINFO="/tmp/prezipfilesinfo"
PREZIPSIZE=0
POSTZIPFILESINFO="/tmp/postzipfilesinfo"
POSTZIPSIZE=0

# Initialize functions

# Convert bytes to KB, MB, GB
convertbytes () {
	BYTES=$1
	if [ $BYTES -ge 1000000000 ]; then
		BYTES=$((BYTES / 1000000000))
		BYTES="$BYTES GB"
	elif [ $BYTES -ge 1000000 ]; then
		BYTES=$((BYTES / 1000000))
		BYTES="$BYTES MB"
	elif [ $BYTES -ge 1000 ]; then
		BYTES=$((BYTES / 1000))
		BYTES="$BYTES KB"
	fi
	echo $BYTES
}

###############################################################################
################################ Setup Logging ################################
###############################################################################

exec 4> >(while read a; do echo $a; echo $a >> $LOGFILE; done) # File descriptor 4 prints to stdout and specified logfile
exec 5>&1 # File descriptor 5 remembers stdout
exec >&4 # Redirect stdout

# Timestamp the log
echo "################################################################################"
echo "Zip performed: $(date)"
echo "################################################################################"



###############################################################################
################################# DO THE WORK #################################
###############################################################################

# Print initial info
echo
echo "pcap directory: $PCAPDIR"
echo "Day to be zipped: $DATETOZIP"
echo "Logfile: $LOGFILE"
echo

# Generate list of files (excluding directories) that will be zipped
ls -calt --time-style +%Y%m%d $PCAPDIR | grep $DATETOZIP | grep -v ^d | awk '{print $7}' > /tmp/list

if [ ! -s /tmp/list ]; then
	echo
	echo "No files in $PCAPDIR modified on $DATETOZIP"
	echo "Nothing to compress."
	echo
	echo
	exit 1
fi

for LINE in `cat /tmp/list`; do
	echo $PCAPDIR$LINE >> $FILELIST
done
rm /tmp/list


# Show info about files before zipping
echo "FILE INFO PRE-ZIP:"
for FILEPATH in `cat $FILELIST`; do
	ls -chalt --time-style +%Y%m%d_%H%M $FILEPATH | tee -a $PREZIPFILESINFO
	FILESIZE=$( ls -l $FILEPATH | awk '{print $5}' )
	PREZIPSIZE=$(( $PREZIPSIZE + $FILESIZE ))
done
CONVPREZIPSIZE=$( convertbytes $PREZIPSIZE ) # Convert Bytes Human-Readable
echo
echo

# Zip the files
for FILEPATH in `cat $FILELIST`; do
	echo "Zipping $FILEPATH"
	gzip $FILEPATH
done
echo
echo

# Show info about files after zipping
echo "FILE INFO POST-ZIP:"
for FILEPATH in `cat $FILELIST`; do
	ls -chalt --time-style +%Y%m%d_%H%M $FILEPATH".gz" | tee -a $PREZIPFILESINFO
	FILESIZE=$( ls -l $FILEPATH".gz" | awk '{print $5}' )
	POSTZIPSIZE=$(( $POSTZIPSIZE + $FILESIZE ))
done
CONVPOSTZIPSIZE=$( convertbytes $POSTZIPSIZE ) # Convert Bytes Human-Readable
echo
echo
echo "Total Prezip filesize: $CONVPREZIPSIZE"
echo "Total Postzip filesize: $CONVPOSTZIPSIZE"
echo "Approximate Compression Ratio: $((PREZIPSIZE / POSTZIPSIZE))"
echo

###############################################################################
################################### CLEANUP ###################################
###############################################################################
	
# Delete temporary files
rm -f $FILELIST
rm -f $PREZIPFILESINFO
rm -f $POSTZIPFILESINFO
