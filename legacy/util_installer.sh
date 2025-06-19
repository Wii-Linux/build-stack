#!/bin/sh

TARGET_DIR=$1
OUTPUT_SCRIPT="setup-fs.sh"
TEMP_FILE=$(mktemp)
FILE_LIST="file_list.txt"

if [ -z "$TARGET_DIR" ]; then
	echo "Usage: $0 <target_directory>"
	exit 1
fi

echo "#!/bin/sh" > "$OUTPUT_SCRIPT"
echo "" >> "$OUTPUT_SCRIPT"
true > "$FILE_LIST"

# Iterate over the entire directory
find "$TARGET_DIR" -exec stat --format="path=%n mode=%a type=\"%F\"" {} \; > "$TEMP_FILE"

while IFS= read -r line; do
	eval "$line"
	case "$type" in
		"symbolic link")
			# Record symlink
			link_target=$(readlink "$path")
			echo "ln -sf \"$link_target\" \"$path\"" >> "$OUTPUT_SCRIPT" ;;

		directory|"regular file")
			# Record permissions
			echo "chmod $mode \"$path\"" >> "$OUTPUT_SCRIPT"
			# Add to file list
			echo "$path" >> "$FILE_LIST" ;;
	esac
done < "$TEMP_FILE"

# Cleanup
rm "$TEMP_FILE"
sed -i "/$FILE_LIST/d" $FILE_LIST
chmod +x "$OUTPUT_SCRIPT"

echo "File list for tar created in $FILE_LIST"

