#!/bin/bash

# Configuration
SOURCE_DIR="/path/to/source"  
BUCKET_NAME="your-bucket-name"  # Destination for the backup 
LOG_FILE="/var/log/backup.log"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MANIFEST_FILE="/var/backup/manifest.txt"  
LOCK_FILE="/var/backup/backup.lock"
URL="http://localhost:4566"
RETENTION_DAYS=30  


log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

clean_old_logs() {
    if [ -f "$LOG_FILE" ]; then
        find "$(dirname "$LOG_FILE")" -name "$(basename "$LOG_FILE")*" -type f -mtime +$RETENTION_DAYS -exec rm {} \;
    fi
}

create_lock() {
    if [ -f "$LOCK_FILE" ]; then
        PID=$(cat "$LOCK_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            log_message "Another backup process is running. Exiting."
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

remove_lock() {
    rm -f "$LOCK_FILE"
}

check_requirements() {
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        log_message "Error: AWS CLI is not installed"
        remove_lock
        exit 1
    fi

    # Check if source directory exists and is readable
    if [ ! -d "$SOURCE_DIR" ] || [ ! -r "$SOURCE_DIR" ]; then
        log_message "Error: Source directory does not exist or is not readable"
        remove_lock
        exit 1
    fi

    # Check if log directory exists and is writable
    LOG_DIR=$(dirname "$LOG_FILE")
    if [ ! -d "$LOG_DIR" ] || [ ! -w "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
    fi

    # Check if manifest directory exists and is writable
    MANIFEST_DIR=$(dirname "$MANIFEST_FILE")
    if [ ! -d "$MANIFEST_DIR" ] || [ ! -w "$MANIFEST_DIR" ]; then
        mkdir -p "$MANIFEST_DIR"
        chmod 755 "$MANIFEST_DIR"
    fi
}

perform_backup() {
    log_message "Starting backup of $SOURCE_DIR"
    
    # Create initial backup if no previous manifest exists 
    if [ ! -f "$MANIFEST_FILE" ]; then
        log_message "Creating initial backup"
        aws --endpoint-url="$URL" s3 sync "$SOURCE_DIR" \
            "s3://$BUCKET_NAME/backup_$TIMESTAMP" \
            --delete 2>> "$LOG_FILE"
            
        if [ $? -eq 0 ]; then
            find "$SOURCE_DIR" -type f -exec sha256sum {} \; > "$MANIFEST_FILE"
            log_message "Initial backup completed successfully"
        else
            log_message "Initial backup failed"
            remove_lock
            exit 1
        fi
        return
    }

    TEMP_MANIFEST="/tmp/temp_manifest_$TIMESTAMP.txt"
    CHANGED_FILES="/tmp/changed_files_$TIMESTAMP.txt"
    
    find "$SOURCE_DIR" -type f -exec sha256sum {} \; > "$TEMP_MANIFEST"

    diff "$MANIFEST_FILE" "$TEMP_MANIFEST" | grep "^>" | cut -d' ' -f3 > "$CHANGED_FILES"

    if [ -s "$CHANGED_FILES" ]; then
        while IFS= read -r file; do
            relative_path=${file#$SOURCE_DIR/}
            aws --endpoint-url="$URL" s3 sync "$file" \
                "s3://$BUCKET_NAME/backup_$TIMESTAMP/$relative_path" 2>> "$LOG_FILE"
            
            if [ $? -ne 0 ]; then
                log_message "Error uploading file: $file"
            fi
        done < "$CHANGED_FILES"
        
        log_message "Incremental backup completed successfully"
        mv "$TEMP_MANIFEST" "$MANIFEST_FILE"
    else
        log_message "No changes detected since last backup"
    fi

    rm -f "$TEMP_MANIFEST" "$CHANGED_FILES"


# Main execution
create_lock
check_requirements
clean_old_logs
perform_backup
remove_lock