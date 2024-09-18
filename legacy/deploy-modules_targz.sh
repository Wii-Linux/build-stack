#!/bin/bash
. ./utils.sh || { echo "failed to load utils.sh"; exit 1; }

fname=modules-"$(datefmt)".tar.gz
cp /srv/other/kernel/4.4/modules.tar.gz "$fname"

file_base_template="modules-"
dest_dir="/srv/www/wii-linux.org/site"
symlinks=("oldold_modules.tar.gz" "old_modules.tar.gz" "latest_modules.tar.gz")

versioned_move
