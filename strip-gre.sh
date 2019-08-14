#!/bin/bash

# Syntax: ./strip-gre.sh path/of/src/dir path/of/dest/dir
# This script takes a src directory and dest directory as arguments.
# Source directory is expected to contain .pcap or .pcap.gz and will output the same format/compression to the destination directory.
# If a file exists in the destination directory with the same name as a file in the source directory, that file will be skipped rather than overwritten.


# Initialize variables
SRCDIR=$1
DESTDIR=$2
SRCFILELIST="/tmp/sourcepcaps"
DESTFILELIST="/tmp/strippedpcaps"
STRIPFILELIST="/tmp/stripthesepcaps"
INITIALLYCOMPRESSED=false
ACTIVEFILEPATH=""
DESTPCAPPATH=""


# Check for proper arguments
if [ -z $1 ]; then # if first argument is null (e.g. there are no arguments)
	echo; echo "Error!"
	echo "Syntax is: strip-gre.sh /path/for/source/pcaps/ /destination/path/for/stripped/pcaps/"; echo
	exit 1 # Quit script
fi
if [ -z $2 ]; then # if there aren't two arguments
	echo; echo "Error!"
	echo "Syntax is: strip-gre.sh /path/for/source/pcaps/ /destination/path/for/stripped/pcaps/"; echo
	exit 1 # Quit script
fi
if [ ! -z $3 ]; then # if there are too many arguments
	echo; echo "Error!"
	echo "Too many arguments!"
	echo "Syntax is: strip-gre.sh /path/for/source/pcaps/ /destination/path/for/stripped/pcaps/"; echo
	exit 1 # Quit script
fi


# Ensure trailing slashes on input directories
if [ "${SRCDIR: -1}" != "/" ]; then
	SRCDIR=$SRCDIR"/"
fi
if [ "${DESTDIR: -1}" != "/" ]; then
	DESTDIR=$DESTDIR"/"
fi

echo
echo "Source directory:	$SRCDIR"
echo "Destination directory:	$DESTDIR"


# Ensure source and destination directories are different
if [ $SRCDIR == $DESTDIR ]; then
	echo; echo "Error!"
	echo "Source and Destination directories cannot be the same"; echo
	exit 1
fi


# Generate list of files to strip and list of files already stripped
ls "$SRCDIR" | grep .pcap > $SRCFILELIST
ls "$DESTDIR" | grep .pcap > $DESTFILELIST
grep --fixed-strings --line-regexp --invert-match --file $DESTFILELIST $SRCFILELIST > $STRIPFILELIST


# Loop through files in list of files to strip
for ACTIVEFILENAME in `cat $STRIPFILELIST`; do

	echo 
	echo $ACTIVEFILENAME
	
	# Set ACTIVEFILEPATH/DESTFILEPATH using source/destination directory and filename; reset flag
	ACTIVEFILEPATH=$SRCDIR$ACTIVEFILENAME
	DESTPCAPPATH=$DESTDIR$ACTIVEFILENAME
	INITIALLYCOMPRESSED=false

	# If file is gzipped: 
	if [ ${ACTIVEFILENAME: -3:3} == ".gz" ]; then 
	
		# Set flag to indicate original status
		INITIALLYCOMPRESSED=true
		echo "File is gzipped"

		# Copy file to tmp folder and update ACTIVEFILEPATH to match new directory
		echo "Copying to tmp folder"
		cp $ACTIVEFILEPATH "/tmp/"$ACTIVEFILENAME	
		ACTIVEFILEPATH="/tmp/"$ACTIVEFILENAME
	
		# Gunzip the file and update ACTIVEFILEPATH to reflect gunzipped file
		echo "Decompressing"
		gunzip $ACTIVEFILEPATH
		ACTIVEFILEPATH=${ACTIVEFILEPATH::-3}
	
		# Remove ".gz" from DESTPCAPPATH
		DESTPCAPPATH=${DESTPCAPPATH::-3}

	fi
	
	# Strip GRE Header 
	echo "Stripping GRE Header"
	editcap -C 14:28 "$ACTIVEFILEPATH" "$DESTPCAPPATH"

	# If originally compressed
	if $INITIALLYCOMPRESSED; then
		# Recompress
		echo "Recompressing"
		gzip $DESTPCAPPATH

		# Delete temporary pcap file copy
		echo "Deleting temporary file"
		rm -f $ACTIVEFILEPATH
	fi


done


# Cleanup
rm -f $SRCFILELIST
rm -f $DESTFILELIST
rm -f $STRIPFILELIST
