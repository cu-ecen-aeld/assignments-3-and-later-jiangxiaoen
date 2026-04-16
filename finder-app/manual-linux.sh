#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1.33.1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
        echo "Using default directory ${OUTDIR} for output"
else
        OUTDIR=$1
        echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    echo "Building kernel..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} Image modules dtbs
fi

echo "Adding the Image in outdir"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
        echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
        sudo rm -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir -p ${OUTDIR}/rootfs/{dev,proc,sys,home,etc}

cd "$OUTDIR"
# Download and extract BusyBox tarball
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
if [ ! -f "${BUSYBOX_TAR}" ]; then
    echo "Downloading BusyBox tarball..."
    wget https://busybox.net/downloads/${BUSYBOX_TAR}
    tar -xjf ${BUSYBOX_TAR}
fi
if [ ! -d "${OUTDIR}/busybox-${BUSYBOX_VERSION}" ]; then
    echo "Extracting BusyBox..."
    tar -xjf ${BUSYBOX_TAR}
fi
cd busybox-${BUSYBOX_VERSION}
# TODO: Configure busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig

# TODO: Make and install busybox
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} -j$(nproc)
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install

cd ${OUTDIR}
# Manually add library dependencies (aarch64 specifics)
mkdir -p ${OUTDIR}/rootfs/lib
# Copy the dynamic linker
cp -a /usr/aarch64-linux-gnu/lib/ld-linux-aarch64.so.1 ${OUTDIR}/rootfs/lib/
# Copy other essential shared libraries
cp -a /usr/aarch64-linux-gnu/lib/libc.so.6 ${OUTDIR}/rootfs/lib/
cp -a /usr/aarch64-linux-gnu/lib/libm.so.6 ${OUTDIR}/rootfs/lib/
cp -a /usr/aarch64-linux-gnu/lib/libresolv.so.2 ${OUTDIR}/rootfs/lib/

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library"

# TODO: Make device nodes
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1

# TODO: Clean and build the writer utility
cd ${FINDER_APP_DIR}/..
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
cp writer ${OUTDIR}/rootfs/home/
cp finder-app/finder.sh ${OUTDIR}/rootfs/home/
cp conf/username.txt ${OUTDIR}/rootfs/home/
cp conf/assignment.txt ${OUTDIR}/rootfs/home/
cp finder-app/finder-test.sh ${OUTDIR}/rootfs/home/
cp finder-app/autorun-qemu.sh ${OUTDIR}/rootfs/home/

# Modify finder-test.sh to use conf/assignment.txt (no ../)
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|' ${OUTDIR}/rootfs/home/finder-test.sh

cat> ${OUTDIR}/rootfs/init <<'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

echo "Boot successful"

exec /bin/sh
EOF

chmod +x ${OUTDIR}/rootfs/init

# TODO: Chown the root directory
sudo chown -R root:root ${OUTDIR}/rootfs

# TODO: Create initramfs.cpio.gz
cd ${OUTDIR}/rootfs
find . | cpio -o -H newc | gzip > ${OUTDIR}/initramfs.cpio.gz
cd ${OUTDIR}

echo "Build completed. Kernel: ${OUTDIR}/Image, initramfs: ${OUTDIR}/initramfs.cpio.gz"
