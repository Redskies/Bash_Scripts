#!/bin/bash
#####################################################
# Script Name:	HDD_Setup.sh 						#
# Author: 		Michael Burkowski               	#
# Date: 		04/13/2017                       	#
# Purpose: 		To setup a report for each      	#
# EWF project and automate basic data gathering  	#
#                                                	#
# Exit Codes:										#
# 1. Illegal Usage: Invalid Arguements				#
# 2. Source files contains non data files			#
# 3. Illegal Usage: Not run as root					#
#													#
#####################################################

# Create Global variables // error checking


if [[ $# -lt 2 ]] ; then 
	printf "Error: Illegal usage.\nUsage: <Output_Directory> <Source_Files>\n"
	exit 1
elif [[ ! -d  $1 ]]; then
	if [[ -f $1 ]]; then
		printf "Error: Output directory cannot be file.\nUsage: <Output_Directory> <Source_Files>\n"
		exit 1
	else mkdir "$1"
	fi 
elif [[ ! -w $1 ]]; then 
	printf "Error: Output directory permission denied.\nUsage: <Output_Directory> <Source_Files>\n"
	exit 1
fi
dest_dir="$1"
shift
if [[ $# -eq 1 ]] ; then
	src_img="$1"
else
	shopt -s nullglob
	src_img="$@"
	src_img=($src_img)
	src_info=${src_img[-1]}
	shopt -u nullglob
	unset 'src_img[-1]'
fi 
for img in ${src_img[@]}; do 
	if [[ ! -r "${img}" ]] ; then
		printf "Error: Source file not readable.\nUsage: <Output_Directory> <Source_Files>\n"
		exit 1
	elif [[  ! "$(file "${img}"| awk '{print $2}' | grep data)" == "data" ]] ; then
		printf "Error: Not a data file(s). Check source files.\nUsage: <Output_Directory <Source_Files>\n"
		exit 2
	fi
done

# Set search keys

src_keys="NTFS|FAT|ExFAT|UFS|EXT|HFS|ISO|9660|YAFFS2|Basic"



# Set up functions

mnt_device() {
		mnt_point="/mnt/tmp" 
		i=0
		if [[ ! -d /mnt/tmp ]]; then 
			mkdir ${mnt_point} >/dev/null 2>/dev/null
			if [[ $(echo $?) -eq 1 ]] ; then
				printf "\nPermission Denied: You must run script as root!\n"
				exit 3
			fi 
		fi
		while [[ $(find ${mnt_point} -maxdepth 0 -empty |grep . -q; echo $?) -eq 1 ]]
			do
				((i++))
				mnt_point="/mnt/tmp${i}" 
				if [[ ! -d ${mnt_point} ]]; then 
					mkdir ${mnt_point} >/dev/null 2>/dev/null
					if [[ $(echo $?) -eq 1 ]] ; then
						printf "\nPermission Denied: You must run script as root!\n"
						exit 3
					fi
				fi 		
			done
		xmount --in ewf ${src_img[@]} ${mnt_point}  >/dev/null 2>/dev/null
		return ${i} 
}

capture_info() {
	if [[ "${src_info}" != "" ]] ; then 
		start_line_no=$(grep -n Acquisition ${src_info} |head -n 1 | awk 'BEGIN {FS=":"}; {print $1}')
		i=0
		if [[ "${start_line_no}" == "" ]] ; then 
			printf "No drive capture information available\n======================================\n"
			return 2
		fi
		while [[ $i -lt 33 ]]; do
			echo $(sed -n ${start_line_no}p ${src_info})
			start_line_no=$((${start_line_no}+1))
			i=$((i+1))
		done
		return 1
	else 
		printf "No drive capture information available\n======================================\n"
		return 2
	fi
} > "${dest_dir}/report.txt"

partition_info() {
	table_check=$(mmls ${src_img[@]} |grep "Cannot determine partition type" | echo $?)
	if [[ ${table_check} -ne 0 ]] ; then
		printf "\n\nPartition Table Information\n===========================\n\n"
		mmls ${src_img[@]} 2>/dev/null
		printf "\n\n"
	fi
} >> "${dest_dir}/report.txt"

file_system_info(){	
	part_offset=($(mmls ${src_img[@]} 2>/dev/null | egrep "${src_keys}" | awk '{print $3}'))
	printf "\nData Partition Information\n==========================\n\n"		
	if [[ ${#part_offset[@]} -gt 0 ]]; then	
		for offset in ${part_offset[@]} ; do 
			printf "\nOFFSET - %s\n\n" ${offset}
			fsstat -o ${offset} ${src_img[@]} | head -n 24
		done
	else
		fsstat ${src_img[@]} | head -n 24
	fi
} >> "${dest_dir}/report.txt"

fs_meta(){
	part_offset=($(mmls ${src_img[@]} 2>/dev/null | egrep "${src_keys}" | awk '{print $3}'))
	part_length=($(mmls ${src_img[@]} 2>/dev/null | egrep "${src_keys}" | awk '{print $5}'))
	if [[ ${#part_offset[@]} -gt 0 ]]; then
		for offset in ${part_offset[@]} ; do
			if [[ ! -d "${dest_dir}/${offset}" ]]; then mkdir "${dest_dir}/${offset}" ; fi 
			fsstat -o ${offset} ${src_img[@]} > "${dest_dir}/${offset}/fsstat.txt" 2>/dev/null
			fls -rp -o ${offset} ${src_img[@]} > "${dest_dir}/${offset}/fls.txt" 2>/dev/null
			jls -o ${offset} ${src_img[@]} > "${dest_dir}/${offset}/jls.txt" 2>/dev/null\
			echo $?
			tsk_recover -o ${offset} ${src_img[@]} "${dest_dir}/${offset}/tsk_recover/" >/dev/null 2>/dev/null
			fls -r -o ${offset} -m "/" ${src_img[@]} > "${dest_dir}/${offset}/body.txt" 2>/dev/null
			mactime -b "${dest_dir}/${offset}/body.txt" > "${dest_dir}/${offset}/timeline.txt" 2>/dev/null
		done
		return 1
	else 
		fsstat ${src_img[@]} > "${dest_dir}/${offset}/fsstat.txt" 2>/dev/null
		fls -rp ${src_img[@]} > "${dest_dir}/${offset}/fls.txt" 2>/dev/null
		jls ${src_img[@]} > "${dest_dir}/${offset}/jls.txt" 2>/dev/null
		tsk_recover ${src_img[@]} "${dest_dir}/${offset}/tsk_recover/" >/dev/null 2>/dev/null
		fls -r -m "/" ${src_img[@]} > "${dest_dir}/${offset}/body.txt" 2>/dev/null
		mactime -b "${dest_dir}/${offset}/body.txt" > "${dest_dir}/${offset}/timeline.txt" 2>/dev/null
		return 2
	fi
}

carve_unalloc(){
	raw_img="${mnt_point}/$(ls ${mnt_point} |grep .dd)"
	part_offset=($(mmls ${src_img[@]} 2>/dev/null | grep Unallocated | awk '{print $3}'))
	part_length=($(mmls ${src_img[@]} 2>/dev/null | grep Unallocated | awk '{print $5}'))
	i=0
	if [[ ${#part_offset[@]} -gt 0 ]]; then
		for offset in ${part_offset[@]} ; do
			if [[ ! -d "${dest_dir}/${offset}" ]]; then mkdir "${dest_dir}/${offset}" ; fi 
			dd if="${raw_img}" of="${dest_dir}/${offset}/unallocated.dd" skip=${part_offset} count="${part_length[i]}" bs=1 \
			>/dev/null 2>/dev/null
			((i++))
		done
		return 1
	photorec /d "${dest_dri}/${offset}/photorec" \
	/cmd "${dest_dir}/${offset}/unallocated.dd" partition_none,fileopt,everything,enable,search >/dev/null 2>/dev/null
	else 
		return 2
	fi
}

main(){
	printf "Script Starting\nMounting devices........"
	mnt_device
	printf "done\nGathering header information........."
	local ret=$?
	if [[ ${ret} -eq 0 ]] ; then mnt_point="/mnt/tmp"; else mnt_point="/mnt/tmp${ret}" ; fi
	capture_info
	printf "done\nGathering partition table........."
	partition_info
	local ret=$?
	if [[ ${ret} -eq 1 ]] ; then printf "done\n" ; else printf "None found, moving on\n" ;fi
	printf "Gathering file system information........."
	file_system_info
	fs_meta
	printf "done\nCarving unallocated data........."
	carve_unalloc
	printf "done\nSuccess\n" 	
	umount ${mnt_point}
	rm -dr ${mnt_point}
	exit 0
}

main
