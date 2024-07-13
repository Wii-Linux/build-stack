#!/bin/sh -e

cd ../build-stack
./c.sh
sudo cp ../boot-stack/loader-img-full/init.sh ../loader-img-src/linuxrc
sudo cp ../boot-stack/loader-img-full/support.sh ../loader-img-src/
sudo cp ../boot-stack/loader-img-full/jit_setup.sh ../loader-img-src/
sudo cp ../boot-stack/loader-img-full/checkBdev.sh ../loader-img-src/
sudo cp ../boot-stack/loader-img-full/network.sh ../loader-img-src/
sudo cp ../boot-stack/loader-img-full/util.sh ../loader-img-src/
sudo cp ../boot-stack/loader-img-full/logging.sh ../loader-img-src/

sudo chown root:root -R ../loader-img-src
sudo rm ../loader*.img ../*.ldr -f
sudo mksquashfs ../loader-img-src ../v4_5_0.ldr
scp ../v4_5_0.ldr root@172.16.4.90:/mnt/sd/wiilinux/v4_5_0.ldr || echo "failed to copy"
