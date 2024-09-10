#!/bin/bash

# Collects per User storage quota

# Node exporter textfile collector directory
COLLECTOR="/opt/node-exporter/textfile-collector"

# Create output file
OUTPUT="${COLLECTOR}/user-storage-quota.$$"
touch ${OUTPUT}

FS_PATH=/export/users

repquota_output=$(repquota --cache --output=csv ${FS_PATH} | tail -n +2)

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

	echo "node_user_storage_quota{user=\"${user}\", blockstatus=\"$blockstatus\", filestatus=\"${filestatus}\", blockused=\"${blockused}\", blocksoftlimit=\"${blocksoftlimit}\", blockhardlimit=\"${blockhardlimit}\", blockgrace=\"${blockgrace}\", fileused=\"${fileused}\", filesoftlimit=\"${filesoftlimit}\", filehardlimit=\"${filehardlimit}\", filegrace=\"${filegrace}\"} " >> ${OUTPUT}

done < <(echo "$repquota_output")

# Rename output file to .prom file for node exporter
mv ${OUTPUT} ${COLLECTOR}/user-storage-quota.prom
