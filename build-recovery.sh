#!/bin/bash -e

. ./util_rootfs.sh || echo "Failed to load util_rootfs.sh" 2>&1

# enable networkmanager for an easy method of managing networks
echo 'nameserver 1.1.1.1' > "$rootfs/etc/resolv.conf"
chroot "$rootfs" xbps-install -Sy NetworkManager dbus usbutils psmisc
chroot "$rootfs" ln -s /etc/sv/dbus /etc/runit/runsvdir/default/dbus
chroot "$rootfs" ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/default/NetworkManager
bash "$baseDir/recovery/banner" > "$rootfs/etc/issue"
chown root:root "$rootfs/etc/issue"

# copy rootfs to a disk image
dd if=/dev/zero of=/tmp/wii_linux_recovery.img
echo 'DONE!!!!  Packaging it up in a known place so we can save it.'
fname="wii-linux-recovery_root-$(date '+%-m-%d-%Y__%H:%M:%S').tar.xz"
popd
tar -c "$rootfs" | xz -T"$(nproc)" -9 > "$fname"

file_base_template="wii-linux-recovery_root-"
dest_dir="/srv/www/wii-linux.org/site"
symlinks=("oldold_recovery.tar.xz" "old_recovery.tar.xz" "latest_recovery.tar.xz")

versioned_move

# get rid of the chroot
rm -rf "$rootfs"
exit 0
