# Node Exporter Textfile Collector Scripts
A collection of scripts to expose additional metrics via the Node Exporter Textfile Collector.

## Prerequisites
- Node exporter installed on the target node.
- Node exporter configured to use the textfile collector (`--collector.textfile.directory`)
- The user running the scripts requires write permission on the textcollector directory.

## Usage
- Install the scripts you wish to use to a suitable directory on the node.
- Update the scripts to set the output directory variable `COLLECTOR` to the directory `node-exporter` has been configured to use for the textfile collector (`--collector.textfile.directory`).
- Add a crontab entry to run the script(s) at the desired interval.

For example:
```
*/5 * * * * /bin/bash /opt/node-exporter/scripts/slurm-gpu-allocation.sh
```

## Known Issues / Future Enhancements
The slurm gpu allocation script (`slurm-gpu-allocation.sh` ) currently only supports a single GRES gpu type per node. Future work would improve parsing the `sinfo` output to support multiple GPU types if present.
