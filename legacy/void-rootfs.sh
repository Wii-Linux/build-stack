#!/bin/bash -e

. ./util_rootfs.sh || echo "Failed to load util_rootfs.sh" 2>&1

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
