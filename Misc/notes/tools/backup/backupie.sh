#!/bin/bash

# Declaring the variables
in_path="/dev/mmcblk0"
out_path="/usb/rpi_ext_1tb_Mems/backup/"
backup_name="backup-$(date +%Y%m%d-%H%M%S).img"
LOG_FILE="$HOME/backupie_script.log"
MAX_LOG_SIZE_MBYTES=50

# Function to handle logging with rotation
log_message() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg" | tee -a "$LOG_FILE"
    
    # Check if log file exceeds max size (convert MB to bytes)
    local max_bytes=$((MAX_LOG_SIZE_MBYTES * 1024 * 1024))
    if [ -f "$LOG_FILE" ]; then
        local current_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ "$current_size" -gt "$max_bytes" ]; then
            # Truncate the file to keep it from growing indefinitely
            # Alternatively, you could move it to .old and create a new one
            echo "Log file exceeded size limit. Rotating..." | tee -a "$LOG_FILE"
            > "$LOG_FILE" 
        fi
    fi
}

cleanup_backups() {
    log_message "Starting cleanup of old backups..."
    
    # Define the pattern based on your naming convention
    # Adjust extension if needed (e.g., *.img.gz for compressed)
    local pattern="backup-*.img*" 
    
    # Count files
    local file_count=$(ls -1 "$out_path"$pattern 2>/dev/null | wc -l)
    
    if [ "$file_count" -le 3 ]; then
        log_message "Only $file_count backups found. No cleanup needed."
        return 0
    fi

    log_message "Found $file_count backups. Keeping latest 3, deleting the rest."

    # List files sorted by modification time (newest first), skip top 3, delete the rest
    # -t: sort by modification time, -r: reverse (newest first)
    ls -1t "$out_path"$pattern | tail -n +4 | while read file; do
        log_message "Deleting old backup: $(basename "$file")"
        rm -f "$file"
    done

    log_message "Cleanup completed."
}

# Function for backup
backup() {

    log_message "Input path is : $in_path"
    log_message "Output path is : $out_path"
    echo
    log_message "-----Starting backup-----"
    echo

    log_message "Running: sudo dd bs=1M if="$in_path" of="$out_path""$backup_name" status=progress"
    sudo dd bs=1M if="$in_path" of="$out_path""$backup_name" status=progress

    echo
    log_message "-----Finished backup, you can find the backup at $out_path$backup_name-----"
    echo
}

# Function for compressed backup
compbackup() {

    log_message "Input path is : $in_path"
    log_message "Output path is : $out_path"
    log_message "Log path is: $LOG_FILE"
    echo
    log_message "-----Starting compressed backup-----"
    echo

    log_message "Running: sudo dd bs=1M if="$in_path" status=progress | gzip > "$out_path""$backup_name".gz"
    sudo dd bs=1M if="$in_path" status=progress | gzip > "$out_path""$backup_name".gz

    echo
    log_message "-----Finished backup, you can find the backup at $out_path$backup_name.gz-----"
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

            log_message Files at previously set output path: "$out_path"
            echo
            ls -la $out_path

            read -p "Enter the filename: " filename
            restore_file="$out_path$filename"

            echo "TIP: Check the device name using commands like lsblk, fdisk -l, df -hT etc. Select the device, not the partition."
            echo
            read -p "Device where you want to restore the backup image to (Ex:- /dev/sdb): " device

            echo
            log_message Restoring from "$restore_file" to "$device"
            echo

            # Restore logic using $restore_file
            sudo dd bs=1M if="$restore_file" of="$device" status=progress
            
            echo
            log_message "-----Restored backup! Check whether the device is booting up-----"
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
            log_message Restoring from "$restore_file" to "$device"
            echo

            # Restore logic using $restore_file
            #sudo dd bs=1M if="$restore_file" of="$device" status=progress

            echo
            log_message "-----Restored backup! Check whether the device is booting up-----"
            echo
            ;;
        *)
            log_message "-----Invalid option. Select 1 or 2-----"
            echo
            ;;
     esac
}

main() {

    # If an argument is passed, skip the menu and run directly
    if [ "$1" = "-auto" ]; then
        compbackup
        return 0
    fi

    echo "Available actions: "
    echo "[1] Normal Backup"
    echo "[2] Normal Restore (Don't be dumb and restore backups of pi from the pi!)"
    echo "[3] Compressed Backup (For big sd cards with a lot of empty space)"
    echo "[4] Cleanup Old Backups (Keep latest 3)"
    
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
        3)
            # Code for compressed backup
            compbackup
            ;;
        4) 
            # Added Case 4 for cleaning backups
            cleanup_backups
            ;;
        *)
            echo "-----Invalid option. Select 1, 2, 3, or 4-----"
            echo
            return 1
            ;;
    esac
    return 0
}

# --- CHECK FOR SPECIAL FLAGS FIRST ---

# 1. Check for Cleanup Flag
if [ "$1" = "-cleanup" ]; then
    cleanup_backups
    exit $?
fi

# 2. Check for Auto Backup Flag
if [ "$1" = "-auto" ]; then
    # Run the main function with -auto to bypass menu
    main -auto
    exit $?
fi

# --- INTERACTIVE MODE (Default) ---
# If no flags were passed, run the menu loop
input_valid=false
while [ "$input_valid" = false ]; do
    if main; then
        input_valid=true
    fi
done