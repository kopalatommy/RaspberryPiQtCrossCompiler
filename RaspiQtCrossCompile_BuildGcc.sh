#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get the number of cores to speed up the compilation
CORES=$(nproc)

# Log that starts the script
echo -e "${GREEN}Starting the script${NC}"

cd ~
# Download gcc sources
mkdir -p gcc_all && cd gcc_all
if [ ! -f binutils-2.40.tar.bz2 ] && [ ! -d binutils-2.40 ]; then
    wget https://ftpmirror.gnu.org/binutils/binutils-2.40.tar.bz2
fi
if [ ! -d binutils-2.40 ]; then
    tar xf binutils-2.40.tar.bz2
fi
if [ ! -f glibc-2.36.tar.bz2 ] && [ ! -d glibc-2.36 ]; then
    wget https://ftpmirror.gnu.org/glibc/glibc-2.36.tar.bz2
fi
if [ ! -d glibc-2.36 ]; then
    tar xf glibc-2.36.tar.bz2
fi
if [ ! -f gcc-12.2.0.tar.gz ] && [ ! -d gcc-12.2.0 ]; then
    wget https://ftpmirror.gnu.org/gcc/gcc-12.2.0/gcc-12.2.0.tar.gz
fi
if [ ! -d gcc-12.2.0 ]; then
    tar xf gcc-12.2.0.tar.gz
fi
if [ ! -d linux ]; then
    git clone --depth=1 https://github.com/raspberrypi/linux
fi

cd gcc-12.2.0
contrib/download_prerequisites

echo -e "${GREEN}Building binutils${NC}"
sudo mkdir -p /opt/cross-pi-gcc
sudo chown $USER /opt/cross-pi-gcc
export PATH=/opt/cross-pi-gcc/bin:$PATH

# Copy the kernel headers
# Check here for specific kernel version: https://www.raspberrypi.com/documentation/computers/linux_kernel.html
echo -e "${GREEN}Copying kernel headers${NC}"
cd ~/gcc_all
cd linux
KERNEL=kernel_2712
make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross-pi-gcc/aarch64-linux-gnu headers_install

# Start building binutils
echo -e "${GREEN}Building binutils${NC}"
cd ~/gcc_all
mkdir build-binutils && cd build-binutils
../binutils-2.40/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --with-arch=armv8 --disable-multilib
make -j $CORES -s
make install

# Patch /libsanitizer/asan/asan_linux.cpp
echo -e "${GREEN}Patching asan_linux.cpp${NC}"
sed -i.back '66i #ifndef PATH_MAX' gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
sed -i.back '67i #define PATH_MAX 4096' gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
sed -i.back '68i #endif' gcc-12.2.0/libsanitizer/asan/asan_linux.cpp

# Start partial build of gcc
echo -e "${GREEN}Starting partial build of gcc${NC}"
cd ~/gcc_all
mkdir build-gcc && cd build-gcc
../gcc-12.2.0/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --enable-languages=c,c++ --disable-multilib
make -j $CORES -s all-gcc
make install-gcc

# Start partial build of glibc
echo -e "${GREEN}Starting partial build of glibc${NC}"
cd ~/gcc_all
mkdir build-glibc && cd build-glibc
../glibc-2.36/configure --prefix=/opt/cross-pi-gcc/aarch64-linux-gnu --build=$MACHTYPE --host=aarch64-linux-gnu --target=aarch64-linux-gnu --with-headers=/opt/cross-pi-gcc/aarch64-linux-gnu/include --disable-multilib libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make -j${CORES} -s csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib
aarch64-linux-gnu-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/aarch64-linux-gnu/lib/libc.so
touch /opt/cross-pi-gcc/aarch64-linux-gnu/include/gnu/stubs.h

# Do more with gcc
echo -e "${GREEN}Continuing with gcc${NC}"
cd ~/gcc_all/build-gcc
make -j${CORES} -s all-target-libgcc
make install-target-libgcc

# Finish building glibc
echo -e "${GREEN}Finishing building glibc${NC}"
cd ~/gcc_all/build-glibc
make -j${CORES} -s
make install

# Finish building gcc
echo -e "${GREEN}Finishing building gcc${NC}"
cd ~/gcc_all/build-gcc
make -j${CORES} -s
make install

# Test the cross compiler
echo -e "${GREEN}Testing the cross compiler${NC}"
aarch64-linux-gnu-gcc --version
