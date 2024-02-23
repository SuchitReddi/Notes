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

# Function for restore
restore() {

    echo "If you want to select an image at another location, select and provide the absolute path."
    echo "[1] You set the image location in the script and want to give just the file name, click 1"
    echo "[2] Image is at other location and you want to give the absolute path, click 2"
    read -p "Click 1 or 2: " loc
    echo
    
    case $loc in
        1)
            # Code for already set path

            echo Files at previously set output path: "$out_path"
            echo
            ls -la $out_path

            read -p "Enter the filename: " filename
            restore_file="$out_path$filename"

            echo "TIP: Check the device name using commands like lsblk, fdisk -l, df -hT etc. Select the device, not the partition."
            echo
            read -p "Device where you want to restore the backup image to (Ex:- /dev/sdb): " device

            echo
            echo Restoring from "$restore_file" to "$device"
            echo

            # Restore logic using $restore_file
            sudo dd bs=1M if="$restore_file" of="$device" status=progress
            
            echo
            echo "-----Restored backup! Check whether the device is booting up-----"
            echo
            ;;
        2)
            # Code for absolute path
            read -p "Enter the absolute path of the image file: " restore_file
            echo

            echo "TIP: Check the device name using commands like lsblk, fdisk -l, df -hT etc. Select the device, not the partition."
            echo
            read -p "Device where you want to restore the backup image to (Ex:- /dev/sdb): " device

            echo
            echo Restoring from "$restore_file" to "$device"
            echo

            # Restore logic using $restore_file
            #sudo dd bs=1M if="$restore_file" of="$device" status=progress

            echo
            echo "-----Restored backup! Check whether the device is booting up-----"
            echo
            ;;
        *)
            echo "-----Invalid option. Select 1 or 2-----"
            echo
            ;;
     esac
}

main() {
    echo "Available actions: "
    echo "[1] Backup"
    echo "[2] Restore"
    
    read -p "Select one action: " action
    echo

    case $action in
        1)
            # Code for backup
            backup
            ;;
        2)
            # Code for restore
            restore
            ;;
        *)
            echo "-----Invalid option. Select 1 or 2-----"
            echo
            ;;
    esac
}

# Call the main function
main
input_valid=false

while [ "$input_valid" = false ]; do
  if main; then
    input_valid=true
  fi
done