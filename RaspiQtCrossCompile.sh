#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Varialbes used by the script
# DeviceIP, the ip address of the target raspberry pi
DeviceIP="192.168.1.149"

QtMajorVersion="6"
QtMinorVersion="4"
QtPatchVersion="0"
QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

while getopts ip: flag
do
    case "${flag}" in
        ip) DeviceIP=${OPTARG};;
    esac
done

# Log that starting script
echo -e "${GREEN}Starting Cross Compile Qt${NC}"
echo -e "${GREEN}Target Device IP: ${DeviceIP}${NC}"
echo -e "${GREEN}Qt Version: ${QtVersion}${NC}"
echo -e

# Check if the raspberry pi is online
echo -e "${GREEN}Checking if Raspberry Pi is online: ${DeviceIP}${NC}"
if ping -c 1 $DeviceIP &> /dev/null
then
    echo -e "${GREEN}Raspberry Pi is online${NC}"
else
    echo -e "${RED}Raspberry Pi is offline${NC}"
    exit
fi

# Get number of threads
echo -e "${GREEN}Getting number of threads${NC}"
threads=$(nproc)
echo -e "${GREEN}Using $threads Threads${NC}"

# Copy the PiSetup.sh script to the target device
echo -e "${GREEN}Copying PiSetup.sh Script${NC}"
scp -r PiSetup.sh pi@$DeviceIP:~/

# Run the PiSetup.sh script
echo -e "${GREEN}Running PiSetup.sh Script${NC}"
ssh pi@$DeviceIP ./PiSetup.sh

# Remove the PiSetup.sh script from the target device
echo -e "${GREEN}Removing PiSetup.sh Script${NC}"
ssh pi@$DeviceIP rm PiSetup.sh

# Set up host
echo -e "${GREEN}Updating host${NC}"
sudo apt update
sudo apt upgrade

# Install packages
echo -e "${GREEN}Installing packages${NC}"
sudo apt-get -y install make build-essential libclang-dev ninja-build gcc git bison python3 gperf pkg-config libfontconfig1-dev libfreetype6-dev libx11-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libatspi2.0-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev build-essential gawk git texinfo bison file wget libssl-dev gdbserver gdb-multiarch libxcb-cursor-dev
# Install other ueful packages
sudo apt-get -y install ccache

# Build CMake
cd ~
git clone https://github.com/Kitware/CMake.git
cd CMake
./bootstrap && make -j${threads} -s && sudo make install

# Make sure success
if [ $? -eq 0 ]
then
    echo -e "${GREEN}CMake Build Successful${NC}"
else
    echo -e "${RED}CMake Build Failed${NC}"
    exit 1
fi

# Start building gcc
echo -e "${GREEN}Building GCC${NC}"
./RaspiQtCrossCompile_BuildGcc.sh

# Start building Qt

# Make directories
cd ~
mkdir rpi-sysroot rpi-sysroot/usr rpi-sysroot/opt
mkdir qt6 qt6/host qt6/pi qt6/host-build qt6/pi-build qt6/src

# Download Qt source
echo -e "${GREEN}Downloading Qt Source${NC}"
cd qt6/src
wget https://download.qt.io/official_releases/qt/${QtMajorVersion}.${QtMinorVersion}/${QtVersion}/single/qt-everywhere-src-${QtVersion}.tar.xz
tar xf qt-everywhere-src-${QtVersion}.tar.xz

# Build Qt for host
echo -e "${GREEN}Building Qt for Host${NC}"
cd ~/qt6/host-build
../src/qt-everywhere-src-${QtVersion}/configure -xplatform linux-g++ -release -opensource -confirm-license -prefix /usr/local/qt6 -nomake tests -nomake examples -skip qtwebengine -skip qtwebview -skip qtwebglplugin -skip qtwebsockets -skip qtwebchannel