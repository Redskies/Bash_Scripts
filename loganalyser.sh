#!/bin/bash
#########################################################
# Script:		loganalyser.sh			#
# Author:		Michael Burkowski		#
# Created:		02/19/2017			#
# Modified:		02/19/2017			#
# Purpose:		Analyses a set of 		#
# message log files from a UNIX/Linux			#
# system and generates a report.			#
#							#
# Usage: ./loganalyser.sh <report_file>	<Source_file>	#
#							#
# Exit Codes: 1 if argument not present			#
#							#
#########################################################

if [[ -z $1 ]] || [[ -z $2 ]]; then	#checks for command line arguement
	printf "Error: File name not supplied.\nUsage: $0 <report_file> <source files>\n"
	exit 1
fi

rpt=$1 #File to contain the report
shift
src=$@ #Source of log files
host=$(head -n1 $(ls -1 message* | head -n1)|awk '{print $4}') #Collects host information

header_info() {
	printf "Log File Analysis Report\n\n" 
	printf "Hostname: %s \nGenerated at: $(date) \nGenerated by: %s \n" ${host}  $(whoami)
} > ${rpt} #This function generates header information

activity() {
	printf "\n\nSuspicious IP Addresses:\n"
	cat ${src} |grep "identification string" | awk '{print $NF}' | sort -u
	printf "\n\nSuspicious Activity:\n"
	cat ${src} |grep "identification string" | awk '{print $1"\t"$2"\t"$3"\t"$NF}' | sort
} >> ${rpt} #This function generates the body of the report


header_info 
activity
exit 0