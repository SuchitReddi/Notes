#!/bin/bash

# Declaring the variables
in_path="/dev/mmcblk0"
out_path="/media/sherl0ck/T7/rpi/backups/"
backup_name="backup-$(date +%Y%m%d-%H%M%S).img"

# Function for backup
backup() {

    echo "Input path is : $in_path"
    echo "Output path is : $out_path"
    echo
    echo "-----Starting backup-----"
    echo

    sudo dd bs=1M if="$in_path" of="$out_path""$backup_name" status=progress

    echo
    echo "-----Finished backup, you can find the backup at $out_path$backup_name-----"
    echo
}

# Calling the backup function
backup