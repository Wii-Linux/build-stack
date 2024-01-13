#!/bin/bash
fatal() {
    printf "\x1b[1;31mFATAL ERROR!!!: \x1b[0m%s\n" "$@"
    exit 1
}

error() {
    printf "\x1b[1;31mERROR: \x1b[0m%s\n" "$@"
}

versioned_move() {
	if [ -z "${fname+x}" ] || [ -z "${symlinks+x}" ] ||
	   [ -z "${file_base_template+x}" ] || [ -z "${dest_dir+x}" ]; then
		fatal "versioned_move: you forgot one of the variables"
	fi


	# Remove existing symlinks
	for f in "${symlinks[@]}"; do
		rm -f "$dest_dir/$f"
	done

	# Move the new file to the destination directory
	mv "$fname" "$dest_dir"

	# Sort files by their timestamp in their name
	sorted_files=( $(find "$dest_dir" -name "$file_base_template"\* | sort) )
	echo "sorted_files = ${sorted_files[*]}"

	# If there are more than 3 files, remove the oldest ones
	echo "num_sorted_files = ${#sorted_files[@]}"
	while [ ${#sorted_files[@]} -gt 3 ]; do
		if [ "${sorted_files[0]}" != "" ]; then
			echo "remove ${sorted_files[0]}"
			rm "${sorted_files[0]}"
		fi
		sorted_files=("${sorted_files[@]:1}")
	done

	for ((i=0; i < ${#symlinks[@]}; i++)); do
		idx=$(( ${#sorted_files[@]} - i - 1 ))
		if [ "$idx" -lt 0 ]; then
			idx=0
		fi
		
		ln -sf "${sorted_files[$idx]}" "$dest_dir/${symlinks[$i]}"
	done
	unset sorted_files symlinks idx file_base_template fname dest_dir
}
