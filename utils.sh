#!/bin/sh
checkValid() {
	if [ "$1" = "$2" ]; then
		error "you can't select $3"
		usage; exit 1
	fi
}

fatal() {
    printf "\033[1;31mFATAL ERROR!!!: \033[0m%s\n" "$@"
    exit 1
}

error() {
    printf "\033[1;31mERROR: \033[0m%s\n" "$@"
}

datefmt() {
    date +"%Y_%m_%d__%H_%M_%S"
}
