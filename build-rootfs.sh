#!/bin/bash -e

usage() {
    echo "$0: Assemble a fully-featured rootfs from an assortment of files.
OPTIONS:
  -a, --already-built: Use the already compiled pieces instead of invoking
                       the scripts to build them automatically.
                       This can save some build time if you're only
                       rebuilding certain pieces.  You can manually
                       invoke the scripts to build only what you need,
                       then run this script with -a to use them.

  -h, --help:          Display this help message.
"
}

. ./utils.sh || { echo "failed to load utils.sh"; exit 1; }
baseDir=$(pwd)


# go parse the arguments so we know what do
for i in "$@"; do
    if [ "$i" = "-a" ] || [ "$i" = "--already-built" ]; then
        # probably part of CI, 
        alreadyBuilt=true
    elif [ "$i" = "-h" ] || [ "$i" = "--help" ]; then
        usage
        exit
    else
        error "Unknown argument \"$i\"!"
        usage
        fatal "Unknown argument... exiting"
    fi
done

cd /wii-linux-tools || fatal "failed to cd to /wii-linux-tools"

echo "installing deps just in case"
xbps-install -y qemu-user-static patch git curl pigz

pushd void-mklive || fatal 'failed to go to void-mklive'
if [ "$alreadyBuilt" != "true" ]; then
    # go build everything from scratch
    
    # check, are we already using the customized mkrootfs?
    if ! grep http://packages.wii-linux.org mkrootfs.sh &> /dev/null; then
        # reset any local changes
        git reset --hard --quiet

        patch -p1 mkrootfs.sh "$baseDir/mkrootfs.patch"
    fi
    cp "$baseDir/"*.plist keys/

    # WARNING: This uses the customized mkrootfs, and will not work with the default
    ./mkrootfs.sh ppc
fi
rootfs=$(cat rootfs_path)
if [ "$rootfs" = "" ]; then
    fatal "Refusing to operate on rootfs that we can't find!"
fi
echo
echo
echo "rootfs dir is $rootfs"
echo
echo
pushd "$rootfs" || fatal "failed to cd to rootfs"

# NOTE: This doesn't use any bandwidth when running on the wii-linux.org server!
# Since wii-linux.org has a public IP directly, it doesn't ever leave the local
# machine, since it knows it's own IP.  It essentially downloads from 127.0.0.1

# download & extract wifi firmware
curl -q https://wii-linux.org/openfwwf-5.2-bin.tar.gz | zcat | tar x

# download & extract the config files
curl https://wii-linux.org/latest-configs.tar.gz | zcat | tar x

# download & extract the kernel modules
curl -q https://wii-linux.org/latest_modules.tar.gz | zcat | tar x


# enable networkmanager for an easy method of managing networks
echo 'nameserver 1.1.1.1' > "$rootfs/etc/resolv.conf"
# install some essentials and some nice-to-haves
chroot "$rootfs" xbps-install -Sy NetworkManager dbus bluez usbutils psmisc
chroot "$rootfs" ln -s /etc/sv/dbus /etc/runit/runsvdir/default/dbus
chroot "$rootfs" ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager
chroot "$rootfs" ln -s /etc/sv/bluetoothd /etc/runit/runsvdir/default/bluetoothd


echo 'DONE!!!!  Packaging it up in a known place so we can save it.'
fname="wii-linux-rootfs-$(date '+%-m-%d-%Y__%H:%M:%S').tar.xz"
popd
tar -c "$rootfs" | xz -T"$(nproc)" -9 > "$fname"

file_base_template="wii-linux-rootfs-"
dest_dir="/srv/www/wii-linux.org/site"
symlinks=("oldold_full.tar.xz" "old_full.tar.xz" "latest_full.tar.xz")

versioned_move

# get rid of the chroot
rm -rf "$rootfs"
exit 0
