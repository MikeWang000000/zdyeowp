#!/bin/bash
set -xeu

BUILDDIR="$PWD/builddir"
BUILD_TRIPLET="$(uname -m)-redhat-linux"
TARGET_TRIPLET="x86_64-linux-gnu"
KERNEL_ARCH="x86"
PREFIX="/opt/cross"

# ====================
# Initialization
mkdir -p "$BUILDDIR"
cd "$BUILDDIR"

echo "fastestmirror=1" >> /etc/yum.conf
yum install -y bison flex gcc make perl rsync


# ====================
# Linux kernel headers
cd "$BUILDDIR"

curl -fLO 'https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.13.tar.xz'
tar xf linux-6.13.tar.xz
cd linux-6.13

make ARCH="$KERNEL_ARCH" defconfig
make ARCH="$KERNEL_ARCH" INSTALL_HDR_PATH="$PREFIX/$TARGET_TRIPLET" headers_install


# ====================
# Binutils
cd "$BUILDDIR"

curl -fLO 'https://ftpmirror.gnu.org/gnu/binutils/binutils-2.44.tar.xz'
tar xf binutils-2.44.tar.xz
cd binutils-2.44

mkdir builddir
cd builddir
../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX/$TARGET_TRIPLET" \
    --program-prefix=""

make -j$(nproc)
make install


# ====================
# GCC (compiler)
cd "$BUILDDIR"
curl -fLO 'https://ftpmirror.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz'

tar xf gcc-14.2.0.tar.xz
cd gcc-14.2.0

curl -fLO "https://ftpmirror.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
curl -fLO "https://ftpmirror.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
curl -fLO "https://ftpmirror.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz"

mkdir gmp mpfr mpc
tar xf "gmp-6.3.0.tar.xz" --strip-components 1 -C gmp
tar xf "mpfr-4.2.1.tar.xz" --strip-components 1 -C mpfr
tar xf "mpc-1.3.1.tar.gz" --strip-components 1 -C mpc

mkdir builddir
cd builddir

../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX" \
    --enable-languages=c,c++ \
    --disable-multilib \
    --with-newlib

make -j$(nproc) all-gcc
make install-gcc


# ====================
# GLIBC (headers)
cd "$BUILDDIR"
curl -fLO 'https://ftpmirror.gnu.org/gnu/glibc/glibc-2.41.tar.xz'

tar xf glibc-2.41.tar.xz
cd glibc-2.41

mkdir builddir
cd builddir

../configure \
    CC="$PREFIX/bin/$TARGET_TRIPLET-gcc" \
    CXX="$PREFIX/bin/$TARGET_TRIPLET-g++" \
    --build="$BUILD_TRIPLET" \
    --host="$TARGET_TRIPLET" \
    --prefix="$PREFIX/$TARGET_TRIPLET" \
    --enable-kernel=3.10.0 \
    --disable-nscd \
    --without-selinux

make install-bootstrap-headers=yes install-headers

cd "$PREFIX/$TARGET_TRIPLET"
mkdir -p include/gnu lib
touch include/gnu/stubs.h lib/libc.so lib/crt1.o lib/crti.o lib/crtn.o


# ====================
# GCC (libgcc)
cd "$BUILDDIR"/gcc-14.2.0/builddir

make -j$(nproc) all-target-libgcc
make install-target-libgcc


# ====================
# GLIBC (final)
cd "$BUILDDIR"/glibc-2.41/builddir

make -j$(nproc)
make install


# ====================
# GCC (final)
cd "$BUILDDIR"/gcc-14.2.0/builddir

make distclean
../configure \
    --build="$BUILD_TRIPLET" \
    --host="$BUILD_TRIPLET" \
    --target="$TARGET_TRIPLET" \
    --prefix="$PREFIX" \
    --includedir="$PREFIX/$TARGET_TRIPLET/include" \
    --enable-languages=c,c++ \
    --disable-multilib

make -j$(nproc)
make install
