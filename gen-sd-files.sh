#!/bin/bash
. ./utils.sh || { echo "failed to load utils.sh"; exit 1; }

xbps-install -y wget

tempDir=$(mktemp --directory --suffix=___wii_linux)

pushd sd_files &> /dev/null || fatal "sd_files doesn't exist\!"
cp -r ./* "$tempDir/"
popd &> /dev/null || fatal "how can we not get back"

pushd "$tempDir" &> /dev/null || fatal "SD files temp dir is dead... what"
wget https://wii-linux.org/latest-kernel.elf -O gumboot/zImage.ngx


file_base_template="wii-linux-sd-files-"
fname="${file_base_template}$(datefmt).tar.gz"

tar c --exclude $file_base_template* ./ | pigz -c9n > "$fname"
dest_dir="/srv/www/wii-linux.org/site"
symlinks=("oldold_sd_files.tar.gz" "old_sd_files.tar.gz" "latest_sd_files.tar.gz")

versioned_move
popd &> /dev/null || fatal "how can we not get back"


