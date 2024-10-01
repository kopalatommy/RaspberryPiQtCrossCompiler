#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'  # Blue
NC='\033[0m' # No Color

BUILD_LOC=$1
SOURCE_CACHE_LOC=$2

# Extra, but not necessary
sudo apt-get -y install help2man gettext

# Get the number of threads to speed up the compilation
threads=$(nproc)

# Log that starts the script
echo -e "${GREEN}Starting build gcc cross compiler${NC}"

if [ -f /opt/cross-pi-gcc/bin/aarch64-linux-gnu-gcc ]; then
    echo -e "${GREEN}Cross compiler already exists${NC}"
    exit 0
fi

download_sources () {
    echo -e "${GREEN}Starting download sources${NC}"

    cd ${SOURCE_CACHE_LOC}
    # Download gcc sources
    if [ ! -f binutils-2.40.tar.bz2 ]; then
        echo -e "${BLUE}Downloading binutils source${NC}"
        wget https://ftpmirror.gnu.org/binutils/binutils-2.40.tar.bz2

        # Handle error
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download bin utils source${NC}"
            return 1
        fi
    fi
    if [ ! -f glibc-2.36.tar.bz2 ]; then
        echo -e "${BLUE}Downloading glibc source${NC}"
        wget https://ftpmirror.gnu.org/glibc/glibc-2.36.tar.bz2

        # Handle error
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download glibc source${NC}"
            return 1
        fi
    fi
    if [ ! -f gcc-12.2.0.tar.gz ]; then
    echo -e "${BLUE}Downloading gcc source${NC}"
        wget https://ftpmirror.gnu.org/gcc/gcc-12.2.0/gcc-12.2.0.tar.gz

        # Handle error
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download gcc source${NC}"
            return 1
        fi
    fi
    if [ ! -d ${SOURCE_CACHE_LOC}/linux ]; then
    echo -e "${BLUE}Downloading rasp linux source${NC}"
        git clone --depth=1 https://github.com/raspberrypi/linux

        # Handle error
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to download rasp linux source${NC}"
            return 0
        fi
    fi

    echo -e "${GREEN}Finished downloading sources${NC}"
    return 0
}

extract_sources () {
    echo -e "${GREEN}Starting extract sources${NC}"
    cd ${BUILD_LOC}

    # If there is an existing build dir, delete it
    if [ -d ${BUILD_LOC}/gcc_all ]; then
        echo -e "${BLUE}Removing old gcc build dir${NC}"
        rm -rf ${BUILD_LOC}/gcc_all

        # Handle error if applicable
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to remove old gcc build dir${NC}"
            return 1
        fi

        # Remove files from install loc files from 
        if [ -d /opt/cross-pi-gcc ]; then
            echo -e "${BLUE}Removing old gcc dir${NC}"
            
            sudo rm -rf /opt/cross-pi-gcc

            # Handle error if applicable
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to remove old gcc dir${NC}"
                return 1
            fi
        fi
    fi

    echo -e "${BLUE}Making build dir${NC}"
    mkdir -p gcc_all && cd gcc_all

    echo -e "${BLUE}Starting extract binutils${NC}"
    tar xf ${SOURCE_CACHE_LOC}/binutils-2.40.tar.bz2

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract bin utils source${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting extract glibc${NC}"
    tar xf ${SOURCE_CACHE_LOC}/glibc-2.36.tar.bz2

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract glibc source${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting extract gcc${NC}"
    tar xf ${SOURCE_CACHE_LOC}/gcc-12.2.0.tar.gz

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to extract gcc source${NC}"
        return 1
    fi

    echo -e "${BLUE}Creating sym link to linux dir${NC}"
    ln -s ${SOURCE_CACHE_LOC}/linux/ ${BUILD_LOC}/gcc_all/linux

    echo -e "${GREEN}Finished extracting gcc sources${NC}"
    return 0
}

create_install_dir () {
    echo -e "${GREEN}Creating install dir${NC}"

    echo -e "${BLUE}sudo mkdir -p /opt/cross-pi-gcc${NC}"
    sudo mkdir -p /opt/cross-pi-gcc

    if [ $? -ne 0 ]; then 
        echo -e "${RED}Failed to make install dir${NC}"
        return 1
    fi

    echo -e "${BLUE}sudo chown $USER /opt/cross-pi-gcc${NC}"
    sudo chown $USER /opt/cross-pi-gcc

    echo -e "${BLUE}Adding to path${NC}"
    export PATH=/opt/cross-pi-gcc/bin:$PATH

    echo -e "${GREEN}Finished creating install dir${NC}"

    return 0
}

download_gcc_prereqs () {
    echo -e "${GREEN}Starting download prereqs${NC}"

    cd ${BUILD_LOC}/gcc_all/gcc-12.2.0

    contrib/download_prerequisites

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to download gcc prereqs${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished download gcc prereqs${NC}"

    return 0
}

# Check here for specific kernel version: https://www.raspberrypi.com/documentation/computers/linux_kernel.html
install_kernel_headers () {
    echo -e "${GREEN}Starting install rpi kernel headers${NC}"

    cd ${BUILD_LOC}/gcc_all/linux

    KERNEL=kernel_2712
    echo -e "${BLUE}Setting kernel to ${KERNEL}${NC}"
    export KERNEL=kernel_2712

    echo -e "${BLUE}Starting headers_install: make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross-pi-gcc/aarch64-linux-gnu headers_install${NC}"
    make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross-pi-gcc/aarch64-linux-gnu headers_install

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install rpi kernel headers${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished download prereqs${NC}"

    return 0
}

build_binutils_step_1 () {
    echo -e "${GREEN}Starting build binutils: step 1${NC}"

    cd ${BUILD_LOC}/gcc_all

    echo -e "${BLUE}Making binutils build dir${NC}"

    mkdir build-binutils && cd build-binutils

    echo -e "${BLUE}Configuring bin utils${NC}"
    echo -e "${BLUE}../binutils-2.40/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --with-arch=armv8 --disable-multilib${NC}"
    ../binutils-2.40/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --with-arch=armv8 --disable-multilib

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to configure bin utils${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting build bin utils${NC}"
    echo -e "${BLUE}make -j$threads${NC}"
    make -j$threads

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make binutils${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting install${NC}"
    echo -e "${BLUE}make install${NC}"
    make install

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install binutils${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build binutils: step 1${NC}"

    return 0
}

patch_asan_linux () {
    echo -e "${GREEN}Starting patch asan_linux${NC}"

    if ! grep -q "#define PATH_MAX" ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp; then
        echo -e "${BLUE}Patching asan_linux${NC}"
        sed -i.back '67i #ifndef PATH_MAX' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
        sed -i.back '68i #define PATH_MAX 4096' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
        sed -i.back '69i #endif' ../gcc-12.2.0/libsanitizer/asan/asan_linux.cpp
    else
        echo -e "${BLUE}The file has already been patched${NC}"
    fi

    echo -e "${GREEN}Finished patch asan_linux${NC}"
    return 0
}

build_gcc_step_2 () {
    echo -e "${GREEN}Starting build gcc: step 2${NC}"

    cd ${BUILD_LOC}/gcc_all

    echo -e "${BLUE}Making build dir${NC}"

    mkdir build-gcc && cd build-gcc

    echo -e "${BLUE}Configuring gcc${NC}"
    echo -e "${BLUE}../gcc-12.2.0/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --enable-languages=c,c++ --disable-multilib${NC}"
    ../gcc-12.2.0/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --enable-languages=c,c++ --disable-multilib

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to configure gcc${NC}"
        return 1
    fi

    echo -e "${BLUE}Starting build gcc${NC}"
    echo -e "${BLUE}make -j $threads all-gcc${NC}"
    make -j$threads all-gcc

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make gcc${NC}"
        return 1
    fi

    echo -e "${BLUE}Installing gcc${NC}"
    echo -e "${BLUE}make install-gcc${NC}"
    make install-gcc

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make gcc${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build gcc: step 2${NC}"

    return 0
}

continue_gcc_step_3 () {
    echo -e "${GREEN}Starting build of glibc: step 3${NC}"

    cd ${BUILD_LOC}/gcc_all

    echo -e "${BLUE}Making build dirs${NC}"

    mkdir build-glibc && cd build-glibc

    echo -e "${BLUE}Configuring glibc${NC}"
    echo -e "${BLUE}../glibc-2.36/configure --prefix=/opt/cross-pi-gcc/aarch64-linux-gnu --build=$MACHTYPE --host=aarch64-linux-gnu --target=aarch64-linux-gnu --with-headers=/opt/cross-pi-gcc/aarch64-linux-gnu/include --disable-multilib libc_cv_forced_unwind=yes${NC}"
    ../glibc-2.36/configure --prefix=/opt/cross-pi-gcc/aarch64-linux-gnu --build=$MACHTYPE --host=aarch64-linux-gnu --target=aarch64-linux-gnu --with-headers=/opt/cross-pi-gcc/aarch64-linux-gnu/include --disable-multilib libc_cv_forced_unwind=yes

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to configure glibc${NC}"
        return 1
    fi 

    echo -e "${BLUE}Starting install boot strap headers${NC}"
    echo -e "${BLUE}make install-bootstrap-headers=yes install-headers${NC}"
    make install-bootstrap-headers=yes install-headers

    echo -e "${BLUE}make -j$threads csu/subdir_lib${NC}"
    make -j$threads csu/subdir_lib

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed on: install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib${NC}"
        return 1
    fi

    echo -e "${BLUE}install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib${NC}"
    install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed on: install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib${NC}"
        return 1
    fi

    echo -e "${BLUE}aarch64-linux-gnu-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/aarch64-linux-gnu/lib/libc.so${NC}"
    aarch64-linux-gnu-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/aarch64-linux-gnu/lib/libc.so

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed on: install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib${NC}"
        return 1
    fi

    echo -e "${BLUE}touch /opt/cross-pi-gcc/aarch64-linux-gnu/include/gnu/stubs.h${NC}"
    touch /opt/cross-pi-gcc/aarch64-linux-gnu/include/gnu/stubs.h

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create stubs.h file${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build of glibc: step 3${NC}"

    return 0
}

continue_build_gcc_step_4 () {
    echo -e "${GREEN}Continuing build of gcc: step 4${NC}"

    cd ${BUILD_LOC}/gcc_all/build-gcc

    echo -e "${BLUE}make -j${threads} -s all-target-libgcc${NC}"
    make -j${threads} -s all-target-libgcc

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed on: make -j${threads} -s all-target-libgcc${NC}"
        return 1
    fi

    echo -e "${BLUE}make install-target-libgcc${NC}"
    make install-target-libgcc

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed on: make install-target-libgcc${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build of glibc: step 4${NC}"

    return 0
}

finish_build_glibc_step_5 () {
    echo -e "${GREEN}Finishing build of glibc: step 5${NC}"

    cd ${BUILD_LOC}/gcc_all/build-glibc

    echo -e "${BLUE}Building glibc${NC}"
    echo -e "${BLUE}make -j${threads}${NC}"
    make -j${threads}

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build glibc${NC}"
        return 1
    fi

    echo -e "${BLUE}Installing glibc${NC}"
    echo -e "${BLUE}make install${NC}"
    make install

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install glibc${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build of glibc: step 5${NC}"

    return 0
}

finish_build_gcc_step_6 () {
    echo -e "${GREEN}Finishing build of gcc: step 6${NC}"

    cd ${BUILD_LOC}/gcc_all/build-gcc

    echo -e "${BLUE}Making gcc${NC}"
    echo -e "${BLUE}make -j${threads}${NC}"
    make -j${threads}

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to make gcc${NC}"
        return 1
    fi

    echo -e "${BLUE}Installing gcc${NC}"
    echo -e "${BLUE}make install${NC}"
    make install

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install gcc${NC}"
        return 1
    fi

    echo -e "${GREEN}Finished build of gcc: step 5${NC}"

    return 0
}

download_sources

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

extract_sources

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

create_install_dir

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

download_gcc_prereqs

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

install_kernel_headers

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

build_binutils_step_1

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

patch_asan_linux

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

build_gcc_step_2

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

continue_gcc_step_3

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

continue_build_gcc_step_4

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

finish_build_glibc_step_5

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

finish_build_gcc_step_6

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build gcc${NC}"
    exit 1
fi

# Test the cross compiler
echo -e "${GREEN}Testing the cross compiler${NC}"
aarch64-linux-gnu-gcc --version
