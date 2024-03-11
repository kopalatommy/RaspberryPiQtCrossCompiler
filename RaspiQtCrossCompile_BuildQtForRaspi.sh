#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

threads=$(nproc)

# Varialbes used by the script
# DeviceIP, the ip address of the target raspberry pi
DeviceIP="$1"

# Version information for the qt version
QtMajorVersion="$2"
QtMinorVersion="$3"
QtPatchVersion="$4"
QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

# Download data from the Raspberry Pi to make a sys root for the cross compile
echo -e "${GREEN}Copying Sysroot${NC}"
rsync -avz --info=progress2 --copy-unsafe-links --rsync-path="sudo rsync" --delete pi@$DeviceIP:/usr rpi-sysroot
ln -s rpi-sysroot/usr/lib rpi-sysroot/lib

# Copy the toolchain file to the source directory
cp toolchain_aarch.cmake ~/qt6/toolchain.cmake

cd $HOME/qt6/pi-build
cmake ../src/qtbase-everywhere-src-6.5.1/ -GNinja -DCMAKE_BUILD_TYPE=Release -DINPUT_opengl=es2 -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF -DQT_HOST_PATH=$HOME/qt6/host -DCMAKE_STAGING_PREFIX=$HOME/qt6/pi -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 -DCMAKE_TOOLCHAIN_FILE=$HOME/qt6/toolchain.cmake -DQT_QMAKE_TARGET_MKSPEC=devices/linux-rasp-pi4-aarch64 -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON -DQT_FEATURE_xlib=ON
cmake --build . --parallel $threads
cmake --install .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully built Qt${NC}"
    exit 0
else 
    echo -e "${RED}Fail to build Qt${NC}"
    exit 1
fi
