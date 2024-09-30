#!/bin/bash
. utils.sh

# Constants
BASE_DIR="/srv/www/wii-linux.org/site/files"

# Variables passed in
source_file=$1
category=$2 # subdir for archiving
naming_template=$3 # naming template, containing keys to get replaced, e.g. {timestamp}.

if [ "$1" = "" ] || [ "$2" = "" ] || [ "$3"  = "" ]; then
	fatal "Missing arguments - this script isn't supposed to be invoked directly!"
fi

if ! [ -f "$1" ]; then
	fatal "Source file missing"
fi

timestamp=$(datefmt)
archive_dir="$BASE_DIR/archive/$category"

# Just in case, ensure base and archive directories exist
mkdir -p "$BASE_DIR"
mkdir -p "$archive_dir"

# Replace "{timestamp}" in the naming template with the actual timestamp and the symlink names
new_file_name="${naming_template/\{timestamp\}/$timestamp}"
latest_symlink="${naming_template/\{timestamp\}/latest}"
old_symlink="${naming_template/\{timestamp\}/old}"

new_file_path="$BASE_DIR/$new_file_name"
latest_symlink_path="$BASE_DIR/$latest_symlink"
old_symlink_path="$BASE_DIR/$old_symlink"

# Start moving stuff
cp "$source_file" "$new_file_path"

# Get list of files that match the naming pattern (e.g. those that contain a timestamp in place of {timestamp})
escaped_naming_template=$(echo "$naming_template" | sed 's/\[{]\([^}]*\)[}]/\\{\\1\\}/g')  # Escape curl braces or else sec complains
matching_files=($(ls "$BASE_DIR" | grep -E "$(echo "$escaped_naming_template" | sed 's/\\{timestamp\\}/[0-9]{4}_[0-9]{2}_[0-9]{2}__[0-9]{2}_[0-9]{2}_[0-9]{2}/')"))

# If we have a "latest" symlink, find the corresponding file and treat it as the most recent build
if [[ -L "$latest_symlink_path" ]]; then
    latest_file=$(readlink -f "$latest_symlink_path")
else
    latest_file=""
fi

# If we have an "old" symlink, find the corresponding file and treat it as the second most recent build
if [[ -L "$old_symlink_path" ]]; then
    old_file=$(readlink -f "$old_symlink_path")
else
    old_file=""
fi

# If we have a current "latest", move it to "old"
if [[ -n "$latest_file" && -f "$latest_file" ]]; then
    echo "Moving latest file to old..."
    if [[ -n "$old_file" && -f "$old_file" ]]; then
        echo "Archiving current old file: $old_file"
        mv "$old_file" "$archive_dir/"
    fi
    # Update "old" symlink to point to what was previously "latest"
    ln -sf "$latest_file" "$old_symlink_path"
fi

# Step 4: Update the "latest" symlink to point to the new build
echo "Linking new build as latest..."
ln -sf "$new_file_path" "$latest_symlink_path"

# Step 5: Archive additional older versions (anything with a timestamp that doesn't match "latest" or "old")
for file in "${matching_files[@]}"; do
    # Skip the current latest and old symlink targets
    if [[ "$file" != "$new_file_name" && "$file" != "$(basename "$latest_file")" && "$file" != "$(basename "$old_file")" ]]; then
        echo "Archiving extra file: $file"
        mv "$BASE_DIR/$file" "$archive_dir/"
    fi
done

echo "Build and archiving process completed."

