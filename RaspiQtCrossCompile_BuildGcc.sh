#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Extra, but not necessary
sudo apt-get -y install help2man gettext

# Get the number of threads to speed up the compilation
threads=$(nproc)

# Log that starts the script
echo -e "${GREEN}Starting build gcc cross compiler${NC}"

cd ~/SourceArchive
# Download gcc sources
if [ ! -f binutils-2.40.tar.bz2 ]; then
    wget https://ftpmirror.gnu.org/binutils/binutils-2.40.tar.bz2
fi
if [ ! -f glibc-2.36.tar.bz2 ]; then
    wget https://ftpmirror.gnu.org/glibc/glibc-2.36.tar.bz2
fi
if [ ! -f gcc-12.2.0.tar.gz ]; then
    wget https://ftpmirror.gnu.org/gcc/gcc-12.2.0/gcc-12.2.0.tar.gz
fi
if [ ! -d ~/SourceArchive/linux ]; then
    git clone --depth=1 https://github.com/raspberrypi/linux
fi

cd ~
if [ -d ~/gcc_all ]; then
    rm -rf ~/gcc_all
fi
mkdir -p gcc_all && cd gcc_all

tar xf ~/SourceArchive/binutils-2.40.tar.bz2 && tar xf ~/SourceArchive/glibc-2.36.tar.bz2 && tar xf ~/SourceArchive/gcc-12.2.0.tar.gz

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to extract gcc sources${NC}"
    exit 1
fi

ln -s ~/SourceArchive/linux .

cd gcc-12.2.0
contrib/download_prerequisites

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to download prereqs${NC}"
    exit 1
fi

echo -e "${GREEN}Building binutils${NC}"
if [ -d /opt/cross-pi-gcc ]; then
    sudo rm -rf /opt/cross-pi-gcc
else
    export PATH=/opt/cross-pi-gcc/bin:$PATH
fi  
sudo mkdir -p /opt/cross-pi-gcc
sudo chown $USER /opt/cross-pi-gcc

# Copy the kernel headers
# Check here for specific kernel version: https://www.raspberrypi.com/documentation/computers/linux_kernel.html
echo -e "${GREEN}Copying kernel headers${NC}"

cd ~/gcc_all/linux
# Make sure there are no changes to the repo
# git stash
KERNEL=kernel_2712
export KERNEL=kernel_2712
make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross-pi-gcc/aarch64-linux-gnu headers_install

# Start building binutils
echo -e "${GREEN}Building binutils${NC}"
cd ~/gcc_all
mkdir build-binutils && cd build-binutils
../binutils-2.40/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --with-arch=armv8 --disable-multilib
make -j $threads
make install

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build binutils${NC}"
fi

# Patch /libsanitizer/asan/asan_linux.cpp
echo -e "${GREEN}Patching asan_linux.cpp${NC}"
if ! grep -q "#define PATH_MAX" ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp; then
    echo "Patching asan_linux"
    sed -i.back '67i #ifndef PATH_MAX' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
    sed -i.back '68i #define PATH_MAX 4096' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
    sed -i.back '69i #endif' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
fi

# Sta$? -ne 0rt partial build of gcc
echo -e "${GREEN}Starting partial build of gcc${NC}"
cd ~/gcc_all
mkdir build-gcc && cd build-gcc
../gcc-12.2.0/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --enable-languages=c,c++ --disable-multilib
make -j $threads all-gcc
make install-gcc

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc step 1${NC}"
    exit 1
fi

# Start partial build of glibc
echo -e "${GREEN}Starting partial build of glibc${NC}"
cd ~/gcc_all
mkdir build-glibc && cd build-glibc
../glibc-2.36/configure --prefix=/opt/cross-pi-gcc/aarch64-linux-gnu --build=$MACHTYPE --host=aarch64-linux-gnu --target=aarch64-linux-gnu --with-headers=/opt/cross-pi-gcc/aarch64-linux-gnu/include --disable-multilib libc_cv_forced_unwind=yes
make install-bootstrap-headers=yes install-headers
make -j$threads csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib
aarch64-linux-gnu-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/aarch64-linux-gnu/lib/libc.so
touch /opt/cross-pi-gcc/aarch64-linux-gnu/include/gnu/stubs.h

# Do more with gcc
echo -e "${GREEN}Continuing with gcc${NC}"
cd ~/gcc_all/build-gcc
make -j${threads} -s all-target-libgcc
make install-target-libgcc
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc step 3${NC}"
    exit 1
fi

# Finish building glibc
echo -e "${GREEN}Finishing building glibc${NC}"
cd ~/gcc_all/build-glibc
make -j${threads}
make install
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build glibc step 4${NC}"
    exit 1
fi

# Finish building gcc
echo -e "${GREEN}Finishing building gcc${NC}"
cd ~/gcc_all/build-gcc
make -j${threads}
make install
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc step 5${NC}"
    exit 1
fi

# Test the cross compiler
echo -e "${GREEN}Testing the cross compiler${NC}"
aarch64-linux-gnu-gcc --version
