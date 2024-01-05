#!/bin/sh
fatal() {
    printf "\x1b[1;31mFATAL ERROR!!!: \x1b[0m%s\n" "$@"
    exit 1
}

error() {
    printf "\x1b[1;31mERROR: \x1b[0m%s\n" "$@"
}
