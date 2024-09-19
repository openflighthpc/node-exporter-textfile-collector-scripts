#!/bin/bash

# This scripts obtains FS quota per-user per-filesytem and writes it to node-exporter collector file

# Node exporter textfile collector directory
COLLECTOR="/opt/node-exporter/textfile-collector"

# Create output file
OUTPUT="${COLLECTOR}/user-xfs-storage-quota.$$"
touch ${OUTPUT}

USER_DIR=/home
QUOTA=/usr/bin/quota
FINDMNT=/usr/bin/findmnt
FS_TYPE=xfs

fs_mount_list=$(findmnt --notruncate --raw --output TARGET,SOURCE,FSTYPE,OPTIONS --types ${FS_TYPE} | tail -n +2 | awk '{print $1}')

#Populating user_list with users from a dir of USER_DIR is set, else collecting from /etc/passwd
if [[ -z "${USER_DIR}" ]]
then
	uid_min=$(grep "^UID_MIN" /etc/login.defs)
	uid_max=$(grep "^UID_MAX" /etc/login.defs)

	user_list=$(awk -F':' -v "min=${uid_min##UID_MIN}" -v "max=${uid_max##UID_MAX}" '{ if (( $3 >= min && $3 <= max )||($3 == "0")) print $1}' /etc/passwd)

else
	user_list=$(ls -1 ${USER_DIR} | grep -v "aquota." | grep -v "lost+found")
	user_list+=$'\nroot'
fi

#echo $user_list

for mount_path in $fs_mount_list
do

	for user in $user_list
	do
    		quota_output=$(${QUOTA} -v --raw-grace -u ${user} --filesystem=${mount_path} 2> /dev/null | tail -n +3| head -1 )
		#echo $quota_output

		if [[ -z "$quota_output" ]] ; then break ; fi

		block_used=$(echo "$quota_output" | awk '{print $2}' | xargs)
		block_quota=$(echo "$quota_output" | awk '{print $3}' | xargs)
		block_limit=$(echo "$quota_output" | awk '{print $4}' | xargs)
		block_grace=$(echo "$quota_output" | awk '{print $5}' | xargs)
		files_used=$(echo "$quota_output" | awk '{print $6}' | xargs)
		files_quota=$(echo "$quota_output" | awk '{print $7}' | xargs)
		files_limit=$(echo "$quota_output" | awk '{print $8}' | xargs)
		files_grace=$(echo "$quota_output" | awk '{print $9}' | xargs)

		if [[ $block_grace == "0" ]]; then
			block_grace=0
		else
			block_grace=1
		fi

		if [[ $files_grace == "0" ]]; then
			files_grace=0
        	else
			files_grace=1
		fi

		echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"block_used\"} ${block_used}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"block_quota\"} ${block_quota}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"block_limit\"} ${block_limit}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"block_grace\"} ${block_grace}" >> ${OUTPUT}

        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"files_used\"} ${files_used}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"files_quota\"} ${files_quota}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"files_limit\"} ${files_limit}" >> ${OUTPUT}
        	echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${mount_path}\", field=\"files_grace\"} ${files_grace}" >> ${OUTPUT}


	done
done

# Rename output file to .prom file for node exporter
mv ${OUTPUT} ${COLLECTOR}/user-xfs-storage-quota.prom
