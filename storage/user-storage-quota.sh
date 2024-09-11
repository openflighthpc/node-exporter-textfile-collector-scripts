#!/bin/bash

# Collects the total and allocated GPUs per node and exposes them as prometheus style metrics
# - Requires the `sinfo` command.
# - Assumed a single gpu GRES type per node.

# Node exporter textfile collector directory
COLLECTOR="/opt/node-exporter/textfile-collector"

# Create output file
OUTPUT="${COLLECTOR}/user-storage-quota.$$"
touch ${OUTPUT}

FS_PATH=/mnt/new_disk
REPQUOTA=/usr/sbin/repquota

repquota_output=$(${REPQUOTA} --raw-grace --cache --output=csv ${FS_PATH} | tail -n +2)

while read line ; do
	user=$(echo "$line" | awk -F',' '{print $1}' | xargs)
	blockstatus=$(echo "$line" | awk -F',' '{print $2}' | xargs)
	filestatus=$(echo "$line" | awk -F',' '{print $3}' | xargs)
	blockused=$(echo "$line" | awk -F',' '{print $4}' | xargs)
	blocksoftlimit=$(echo "$line" | awk -F',' '{print $5}' | xargs)
	blockhardlimit=$(echo "$line" | awk -F',' '{print $6}' | xargs)
	blockgrace=$(echo "$line" | awk -F',' '{print $7}' | xargs)
	fileused=$(echo "$line" | awk -F',' '{print $8}' | xargs)
	filesoftlimit=$(echo "$line" | awk -F',' '{print $9}' | xargs)
	filehardlimit=$(echo "$line" | awk -F',' '{print $10}' | xargs)
	filegrace=$(echo "$line" | awk -F',' '{print $11}' | xargs)

	if [[ $blockstatus == "ok" ]]; then
		blockstatus=0
	else
		blockstatus=1
	fi

	if [[ $filestatus == "ok" ]]; then
		filestatus=0
        else
		filestatus=1
	fi

	echo "node_user_storage_quota_block_status{user=\"${user}\"} ${blockstatus}" >> ${OUTPUT}
        echo "node_user_storage_quota_file_status{user=\"${user}\"} ${filestatus}" >> ${OUTPUT}
        echo "node_user_storage_quota_block_used{user=\"${user}\"} ${blockused}" >> ${OUTPUT}
        echo "node_user_storage_quota_block_soft_limit{user=\"${user}\"} ${blocksoftlimit}" >> ${OUTPUT}
        echo "node_user_storage_quota_block_hard_limit{user=\"${user}\"} ${blockhardlimit}" >> ${OUTPUT}
        echo "node_user_storage_quota_block_grace{user=\"${user}\"} ${blockgrace}" >> ${OUTPUT}
        echo "node_user_storage_quota_file_used{user=\"${user}\"} ${fileused}" >> ${OUTPUT}
        echo "node_user_storage_quota_file_soft_limit{user=\"${user}\"} ${filesoftlimit}" >> ${OUTPUT}
        echo "node_user_storage_quota_file_hard_limit{user=\"${user}\"} ${filehardlimit}" >> ${OUTPUT}
        echo "node_user_storage_quota_file_grace{user=\"${user}\"} ${filegrace}" >> ${OUTPUT}

	#echo "node_user_storage_quota{user=\"${user}\", blockstatus=\"$blockstatus\", filestatus=\"${filestatus}\", blockused=\"${blockused}\", blocksoftlimit=\"${blocksoftlimit}\", blockhardlimit=\"${blockhardlimit}\", blockgrace=\"${blockgrace}\", fileused=\"${fileused}\", filesoftlimit=\"${filesoftlimit}\", filehardlimit=\"${filehardlimit}\", filegrace=\"${filegrace}\" } " >> ${OUTPUT}

done < <(echo "$repquota_output")

# Rename output file to .prom file for node exporter
mv ${OUTPUT} ${COLLECTOR}/user-storage-quota.prom
