#!/bin/bash
#########################################################
# Script:		web_loganalyser.sh		#
# Author:		Michael Burkowski		#
# Created:		02/19/2017			#
# Modified:		02/19/2017			#
# Purpose:		Analyses a set of 		#
# message log files from a UNIX/Linux webserver		#
# system and generates a report.			#
#							#
# Usage: ./loganalyser.sh <report_file>	<Source_files>	#
# 							#
# Source file can be as many log files as needed or 	#
# a group of files such as path/to/files*		#
#							#
#							#
# Exit Codes: 1 if argument not present			#
#							#
#########################################################

#Checks for command line arguement to ensure input is a file

if [[ $# -eq 0 ]] ; then
	printf "Error: File name not supplied.\nUsage: <report_file> <source_file>\n"
	exit 1
elif ~ [[ -w $1 ]] ; then
	printf "Report file error: permission denied\n" 
	exit 1
fi
for file in $@ ; do
	if ! [[ -f $file ]] ; then 
		printf "Error: File name not supplied.\nUsage: <report_file> <source_file>\n"
		exit 1 
	elif ! [[ -r $file ]] ; then
		printf "File error: permission denied \n" 
		exit1
	fi
done


rpt=$1 	#File to contain the report
shift	#Moves arguements over to the left. Removal will break script.
src=$@	#Source of log files

#Set global variables. Srch_Keys are used to sort the timestamps of the log file
srch_keys="-k 4.9,4.12n -k 4.5,4.7M -k 4.2,4.3n -k 4.14,4.15n -k 4.17,4.18n -k 4.20,4.21n"
head="$(cat ${src} | sort -t ' ' ${srch_keys} | head -n 1 | awk -F ' ' '{print substr($4,2)}')"
tail="$(cat ${src} | sort -t ' ' ${srch_keys} | tail -n 1 | awk -F ' ' '{print substr($4,2)}')"
uniq_ip="$(cat ${src} | awk -F ' ' '{print $1}' | sort -u | wc -l)"

header_info() {
	printf "Log File Analysis Report\n\n" 
	printf "Source Files: %s \nGenerated at: $(date) \nGenerated by: %s \n" ${src}  $(whoami)
} > ${rpt} #This function generates header information

activity() {
	printf "Log start time: %s\nLog end time: %s\nNumber of Unique IP Addresses: %s\n\n" ${head} ${tail} ${uniq_ip}
	printf "Unique IP Addresses:\n\n"
	cat ${src} | awk -F ' ' '{print $1}' | sort -u
} >> ${rpt} #This function generates the body of the report


header_info
activity
exit 0 
