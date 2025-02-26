#!/bin/bash
checkValid() {
	if [ "$1" = "$2" ]; then
		error "you can't select $3"
		usage; exit 1
	fi
}

fatal() {
    printf "\x1b[1;31mFATAL ERROR!!!: \x1b[0m%s\n" "$@"
    exit 1
}

error() {
    printf "\x1b[1;31mERROR: \x1b[0m%s\n" "$@"
}

datefmt() {
    date +"%Y_%m_%d__%H_%M_%S"
}
