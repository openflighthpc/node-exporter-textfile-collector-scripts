#!/bin/bash

# Collects the total and allocated GPUs per node and exposes them as prometheus style metrics
# - Requires the `sinfo` command.
# - Assumed a single gpu GRES type per node.

# Node exporter textfile collector directory
COLLECTOR="/opt/node-exporter/textfile-collector"

# Create output file
OUTPUT="${COLLECTOR}/slurm-gpu-allocation.$$"
touch ${OUTPUT}

# Parse sinfo output to collect total GPUs
sinfo_output=$(/usr/bin/sinfo -a --Format=NodeHost:40,Gres:40,GresUsed:40,StateLong:40 -h 2>/dev/null)

while read line ; do
	node=$(echo "$line" | awk '{print $1}' | xargs)
	gres=$(echo "$line" | awk '{print $2}' | xargs)
	gres_used=$(echo "$line" | awk '{print $3}' | xargs)
	state=$(echo "$line" | awk '{print $4}' | xargs)

	ident=""
	amount=""
	used=""

	# Check GRES output matches expected format for gpu
	# gpu:<ident>:<amount>
	gres_regex=".*gpu:([^:]*):([0-9]*).*"

	if [[ "$gres" =~ $gres_regex ]] ; then

		ident="${BASH_REMATCH[1]}"
		amount="${BASH_REMATCH[2]}"

		# Check GRES used output matches expected format for gpu
		used_regex=".*gpu:$ident:([0-9]*).*"

		if [[ "$gres_used" =~ $used_regex ]] ; then
			used="${BASH_REMATCH[1]}"

			echo "slurm_node_gpu_total{node=\"${node}\", gres=\"$ident\", status=\"${state}\"} ${amount}" >> ${OUTPUT}
			echo "slurm_node_gpu_alloc{node=\"${node}\", gres=\"$ident\", status=\"${state}\"} ${used}" >> ${OUTPUT}
		fi

	fi
done < <(echo "$sinfo_output")

# Rename output file to .prom file for node exporter
mv ${OUTPUT} ${COLLECTOR}/slurm-gpu-allocation.prom
