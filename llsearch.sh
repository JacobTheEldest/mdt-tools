#!/bin/bash

# llsearch.sh v0.1
# Written by Jacob S. Steward - jacob.steward@us.af.mil
# Created: 20191126
# Last Updated: 20191203

# CHANGELOG:
# v0.1 - Outline the script


# EXPECTATIONS:
# - devices.csv
# 	- Expects an input file named "devices.csv" containing info in the format "IP_Address,Device Name" on each line.
# 	- One per line, with no blank lines or lines containing anything else. Ex1: "10.1.2.1,GCS1"
# - Directory of PCAP files


# Functionality:
# - Starts at the pcap containing the specified time and looks for lost link indicators
# - If it does not find lost link indicators within a certain time range of the specified point, report no lost link found
# - If it finds indicators of a lost link, determine the start and end, moving into other PCAPs as appropriate
 

# OUTPUT:
# - A report on the lost link for the specified time range.
# - Include start and end time for the lost link
# - Metrics
# 	- Number of total lost link packets out of total number of packets
# 	- Average packets per second


# USAGE:
# - Ensure mdt-tools directory is in the PATH
# 	- ex: dockervm:/etc/profile.d/extrapaths.sh
# 		if [ -d /home/assessor/mdt-tools ]; then
# 			pathprepend /home/assessor/mdt-tools
# 		fi
# - Ensure llsearch.sh is executable
# - llsearch.sh GCS# STARTDATE STARTTIME
# 	- Ex: llsearch.sh 5109 20190703 0356


# TODO:
# - Determine how far the script should search before giving up
# - Translate GCS# into an ip address using devices.csv
# - Determine lost link via packet stuffing and via lack of packets


################################################################################
######## Initial Setup                                                  ########
################################################################################

######## Declare Default Variables
CSV_PATH="/home/assessor/mdt-tools/acnidconfgen/devices.csv"
PCAP_PATH="/data/moloch/raw/"

######## Function Declarations


######## Support CLI arguments

# Provides help if no flags or flags -h or --help are used
if [ -z $1 ] || [ $1 == "-h" ] || [ $1 == "--help" ]; then
	echo
	echo "Syntax: ./llsearch.sh GCS# DATE TIME [/path/to/devices.csv] [/path/to/pcaps]"
	echo
	echo "GCS# is the gcs to be checked"
	echo "DATE is the day of the event"
	echo "TIME is a time included in the event"
	echo "/path/to/pcaps   - (Optional) Directory that the pcap files are stored in."
	echo
	echo "Example: ./llsearch.sh 5109 20190703 0356 [/path/to/pcaps]"
	echo
	exit 1 # Quit script
fi

# Check for proper number of arguments
if [ $6 ]; then # if there are too many arguments
	echo; echo "Error! Too many arguments!"; echo
	echo "See help for more info (-h or --help)"; echo
	exit 1 # Quit script
fi


######## Initialize Variables
GCS=$1
DATE=$2
TIME=$3
if [ -z $4 ]; then CSV_PATH=$4"/"; fi
if [ -z $5 ]; then PCAP_PATH=$5"/"; fi


######## Ensure this script was run as root


######## Read contents of input files
IPS=($(grep "GCS $GCS" $CSV_PATH | cut -d ',' -f1))


################################################################################
######## Perform the Search                                             ########
################################################################################

######## Generate a list of available pcaps



################################################################################
######## Generate the Report                                            ########
################################################################################


