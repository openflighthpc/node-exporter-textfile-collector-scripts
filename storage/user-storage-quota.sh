#!/bin/bash

# This scripts obtains FS quota per-user per-filesytem and writes it to node-exporter collector file

# Node exporter textfile collector directory
COLLECTOR="/opt/node-exporter/textfile-collector"

# Create output file
OUTPUT="${COLLECTOR}/user-storage-quota.$$"
touch ${OUTPUT}


QUOTA=/usr/bin/quota
LFS=/usr/bin/lfs
USER_DIR=""
FS_TYPE=""

function get_user_list()
{
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

    echo $user_list
}



function get_quota()
{
    user_list=$(get_user_list)
    for user in $user_list
    do
        quota_output=$(${QUOTA} -v --raw-grace --user ${user} --show-mntpoint --hide-device 2> /dev/null | grep ${MOUNT_PATH} )
	if [[ -z "$quota_output" ]] ; then continue ; fi

	while read line
	do

		target=$(echo "$quota_output" | awk '{print $1}' | xargs)

		if [[ "$MOUNT_PATH" != "$target" ]] ; then continue ; fi

		blocks_used=$(echo "$quota_output" | awk '{print $2}' | xargs)
		blocks_quota=$(echo "$quota_output" | awk '{print $3}' | xargs)
		blocks_limit=$(echo "$quota_output" | awk '{print $4}' | xargs)
		blocks_grace=$(echo "$quota_output" | awk '{print $5}' | xargs)
		files_used=$(echo "$quota_output" | awk '{print $6}' | xargs)
		files_quota=$(echo "$quota_output" | awk '{print $7}' | xargs)
		files_limit=$(echo "$quota_output" | awk '{print $8}' | xargs)
		files_grace=$(echo "$quota_output" | awk '{print $9}' | xargs)

		if [[ $blocks_grace == "0" ]]; then
			blocks_grace=0
		else
			blocks_grace=1
		fi

		if [[ $files_grace == "0" ]]; then
			files_grace=0
        	else
			files_grace=1
		fi

		echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${MOUNT_PATH}\", blocks_used=\"${blocks_used}\", blocks_quota=\"${blocks_quota}\", blocks_limit=\"${blocks_quota}\", blocks_grace=\"${blocks_grace}\", files_used=\"${files_used}\", files_quota=\"${files_quota}\", files_limit=\"${files_limit}\", files_grace=\"${files_grace}\"}" 0 >>${OUTPUT}

	done < <(echo "$quota_output")
    done
    # Rename output file to .prom file for node exporter
    mv ${OUTPUT} ${COLLECTOR}/user-storage-quota.prom

}


function get_lustre_quota()
{
    user_list=$(get_user_list)

    for user in $user_list
	do
        quota_output=$(${LFS} quota -u ${user} ${MOUNT_PATH} 2> /dev/null | tail -n +3| head -1)

		if [[ -z "$quota_output" ]] ; then break ; fi

		kbs_used=$(echo "$quota_output" | awk '{print $2}' | xargs)
		blocks_quota=$(echo "$quota_output" | awk '{print $3}' | xargs)
		blocks_limit=$(echo "$quota_output" | awk '{print $4}' | xargs)
		blocks_grace=$(echo "$quota_output" | awk '{print $5}' | xargs)
		files_used=$(echo "$quota_output" | awk '{print $6}' | xargs)
		files_quota=$(echo "$quota_output" | awk '{print $7}' | xargs)
		files_limit=$(echo "$quota_output" | awk '{print $8}' | xargs)
		files_grace=$(echo "$quota_output" | awk '{print $9}' | xargs)

		if [[ $block_grace == "-" ]]; then
			block_grace=0
		else
			block_grace=1
		fi

		if [[ $files_grace == "-" ]]; then
			files_grace=0
        	else
			files_grace=1
		fi

		echo "node_user_storage_quota{user=\"${user}\", fs_type=\"${FS_TYPE}\", mount_path=\"${MOUNT_PATH}\", kbs_used=\"${kbs_used}\", blocks_quota=\"${blocks_quota}\", blocks_limit=\"${blocks_quota}\", blocks_grace=\"${blocks_grace}\", files_used=\"${files_used}\", files_quota=\"${files_quota}\", files_limit=\"${files_limit}\", files_grace=\"${files_grace}\"}" 0 >>${OUTPUT}

	done
 
 	# Rename output file to .prom file for node exporter
    	mv ${OUTPUT} ${COLLECTOR}/user-storage-quota.prom
}



function help()
{
    echo "Usage: user-storage-quota.sh  --user-dir <user-dir> --fs-type <fs-type> --mount-path <mount-path>
               [ --help ]"
}



LONG=user-dir:,fs-type:,mount-path:,help
OPTS=$(getopt --name ser-storage-quota.sh --options ''  --longoptions $LONG -- "$@")
VALID_ARGUMENTS=$# # Returns the count of arguments that are in short or long options

if [ "$VALID_ARGUMENTS" -eq 0 ]; then
  help
  exit 1
fi

eval set -- "$OPTS"

while :
do
  case "$1" in
    --user-dir )
      USER_DIR="$2"
      shift 2
      ;;
    --fs-type )
      FS_TYPE="$2"
      shift 2
      ;;
    --mount-path )
      MOUNT_PATH="$2"
      shift 2
      ;;
    -h | --help)
      help
      exit 0
      ;;
    --)
      shift;
      break
      ;;
    *)
      echo "Unexpected option: $1"
      help
      exit 1
      ;;
  esac
done


case "$FS_TYPE" in
    "xfs" | "ext4" | "nfs" )
        get_quota
        ;;

    "lustre" )
        get_lustre_quota
        ;;

    *)
      echo "Unexpected --fs-type option: $FS_TYPE"
      help
      exit 1
      ;;

esac
