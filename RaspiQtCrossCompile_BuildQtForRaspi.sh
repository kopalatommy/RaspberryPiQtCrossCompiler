#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

BUILD_LOC=$5
SOURCE_CACHE_LOC=$7
BUILD_LABEL=$8

threads=$(nproc)

# Varialbes used by the script
# DeviceIP, the ip address of the target raspberry pi
DeviceIP="$1"

# Version information for the qt version
QtMajorVersion="$2"
QtMinorVersion="$3"
QtPatchVersion="$4"
QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

account=$6

echo "Build Loc: ${BUILD_LOC}"

sudo apt-get install -y libdouble-conversion-dev

# Make the build dir
mkdir -p ${BUILD_LOC}/${BUILD_LABEL}

# Make build and install dirs
mkdir -p ${BUILD_LOC}/${BUILD_LABEL}-build
mkdir -p ${BUILD_LOC}/${BUILD_LABEL}

# Copy the toolchain file to the source directory
cp toolchain_aarch.cmake ${BUILD_LOC}/toolchain.cmake

cd ${BUILD_LOC}/${BUILD_LABEL}-build
# cmake ../src/qt-everywhere-src-$QtVersion/ -GNinja -DCMAKE_BUILD_TYPE=Release -DINPUT_opengl=es2 -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DQT_HOST_PATH=${BUILD_LOC}/host -DCMAKE_STAGING_PREFIX=${BUILD_LOC}/pi -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 -DCMAKE_TOOLCHAIN_FILE=${BUILD_LOC}/toolchain.cmake -DQT_QMAKE_TARGET_MKSPEC=devices/linux-rasp-pi4-aarch64 -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON
# cmake ../src/qt-everywhere-src-$QtVersion/ -GNinja -DCMAKE_BUILD_TYPE=Release -DINPUT_opengl=es2 -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DQT_HOST_PATH=${BUILD_LOC}/host -DCMAKE_STAGING_PREFIX=${BUILD_LOC}/pi -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 -DCMAKE_TOOLCHAIN_FILE=${BUILD_LOC}/toolchain.cmake -DQT_QMAKE_TARGET_MKSPEC=devices/linux-rasp-pi4-aarch64 -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON
BUILD_LOC=$BUILD_LOC TARGET_SYSROOT=${BUILD_LOC}/${BUILD_LABEL}-sysroot $SOURCE_CACHE_LOC/qt-everywhere-src-$QtVersion/configure -release -opengl es2 -skip qtmultimedia -skip qtspeech -nomake examples -nomake tests -qt-host-path ${BUILD_LOC}/host -extprefix ${BUILD_LOC}/${BUILD_LABEL} -prefix /usr/local/qt6 -device linux-rasp-pi4-aarch64 -device-option CROSS_COMPILE=/opt/cross-pi-gcc/bin/aarch64-linux-gnu- -- -DCMAKE_TOOLCHAIN_FILE=${BUILD_LOC}/toolchain.cmake -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON -DBUILD_LOC=${BUILD_LOC} -DCMAKE_CXX_COMPILER_LAUNCHER=ccache

# Exit if failed
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to configure Qt${NC}"
    exit 1
fi

cmake --build . --parallel $threads

# Exit if failed
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to build Qt${NC}"
    exit 1
fi

cmake --install .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully built Qt${NC}"
    exit 0
else 
    echo -e "${RED}Failed to build Qt${NC}"
    exit 1
fi
