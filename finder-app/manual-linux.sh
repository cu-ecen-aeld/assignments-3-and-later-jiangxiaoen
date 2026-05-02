#!/bin/bash

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1.33.1          
FINDER_APP_DIR=$(realpath $(dirname $0))


ARCH=arm
CROSS_COMPILE=arm-linux-gnueabihf-

if [ $# -lt 1 ]
then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}


cd "${OUTDIR}"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi


if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/zImage ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    echo "Building kernel (vexpress_defconfig)..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} vexpress_defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} zImage modules dtbs
fi


echo "Adding the zImage to outdir as Image"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/zImage ${OUTDIR}/Image


echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm -rf ${OUTDIR}/rootfs
fi


mkdir -p ${OUTDIR}/rootfs/{dev,proc,sys,home,etc}


cd "$OUTDIR"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
if [ ! -f "${BUSYBOX_TAR}" ]; then
    echo "Downloading BusyBox tarball..."
    wget https://busybox.net/downloads/${BUSYBOX_TAR}
fi
if [ ! -d "${OUTDIR}/busybox-${BUSYBOX_VERSION}" ]; then
    echo "Extracting BusyBox..."
    tar -xjf ${BUSYBOX_TAR}
fi
cd busybox-${BUSYBOX_VERSION}

echo "Configuring BusyBox (static build)..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config

echo "Building and installing BusyBox..."
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install


cat > ${OUTDIR}/rootfs/init << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
exec /bin/sh
EOF
chmod +x ${OUTDIR}/rootfs/init


sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1


cd ${FINDER_APP_DIR}/..

if [ ! -f writer.c ]; then
    echo "ERROR: writer.c not found in repository root"
    exit 1
fi
make clean
make CROSS_COMPILE=${CROSS_COMPILE} CFLAGS="-static"


cp writer ${OUTDIR}/rootfs/home/
cp finder-app/finder.sh ${OUTDIR}/rootfs/home/
cp conf/username.txt ${OUTDIR}/rootfs/home/
cp conf/assignment.txt ${OUTDIR}/rootfs/home/
cp finder-app/finder-test.sh ${OUTDIR}/rootfs/home/
cp finder-app/autorun-qemu.sh ${OUTDIR}/rootfs/home/


sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|' ${OUTDIR}/rootfs/home/finder-test.sh


sed -i '1s|#!/bin/bash|#!/bin/sh|' ${OUTDIR}/rootfs/home/finder.sh


sudo chown -R root:root ${OUTDIR}/rootfs

cd ${OUTDIR}/rootfs
find . | cpio -o -H newc | gzip > ${OUTDIR}/initramfs.cpio.gz

echo "Build completed. Kernel: ${OUTDIR}/Image, initramfs: ${OUTDIR}/initramfs.cpio.gz"
