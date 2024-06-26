#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Varialbes used by the script
# DeviceIP, the ip address of the target raspberry pi
DeviceIP="192.168.1.146"
export DeviceIP="192.168.1.146"

QtMajorVersion="6"
QtMinorVersion="6"
QtPatchVersion="2"
QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

export QtMajorVersion="6"
export QtMinorVersion="6"
export QtPatchVersion="2"
export QtVersion="$QtMajorVersion.$QtMinorVersion.$QtPatchVersion"

architecture=aarch64
#architecture=armhf

# Sets the location where the app will be build
BUILD_LOC=$HOME/PiQt_${architecture}_${QtMajorVersion}_${QtMinorVersion}_${QtPatchVersion}

if [ $# -ge 1 ]; then
    echo "Setting build loc to $HOME/$1 from $BUILD_LOC"
    BUILD_LOC=$HOME/$1
fi

SOURCE_CACHE_LOC="${HOME}/PiQtSourceCache/"

while getopts ip: flag
do
    case "${flag}" in
        ip) DeviceIP=${OPTARG};;
    esac
done

# Log that starting script
echo -e "${GREEN}Starting Cross Compile Qt${NC}"
echo -e "Target Device IP: ${DeviceIP}"
echo -e "Qt Version: ${QtVersion}"
echo -e "Build Loc: ${BUILD_LOC}"

# Check if the raspberry pi is online
echo -e "${GREEN}Checking if Raspberry Pi is online: ${DeviceIP}${NC}"
if ping -c 1 $DeviceIP &> /dev/null
then
    echo -e "${GREEN}Raspberry Pi is online${NC}"
else
    echo -e "${RED}Raspberry Pi is offline${NC}"
    exit
fi

# Try to create the build die
echo -e "${Green}Creating build dir:${BLUE}${BUILD_LOC}${NC}"
mkdir -p $BUILD_LOC
if [ $? -eq 0 ]
then
    echo -e "${GREEN}Successfully created build loc${NC}"
else
    echo -e "${RED}Failed to create build loc${NC}"
    exit 1
fi

# Copy ssh key to the target device
echo -e "${GREEN}Copying SSH Key${NC}"
ssh-copy-id pi@$DeviceIP

# Get number of threads
echo -e "${GREEN}Getting number of threads${NC}"
threads=$(nproc)
export threads=$(nproc)
echo -e "${GREEN}Using $threads Threads${NC}"

# Copy the PiSetup.sh script to the target device
echo -e "${GREEN}Copying PiSetup.sh Script${NC}"
scp RaspiQtCrossCompile_PiSetup.sh pi@$DeviceIP:~/

# Run the PiSetup.sh script
echo -e "${GREEN}Running PiSetup.sh Script${NC}"
ssh pi@$DeviceIP ./RaspiQtCrossCompile_PiSetup.sh

# Make sure success
if [ $? -eq 0 ]
then
    echo -e "${GREEN}Finished device setup${NC}"
else
    echo -e "${RED}Failed to setup device${NC}"
    exit 1
fi

# Remove the PiSetup.sh script from the target device
echo -e "${GREEN}Removing PiSetup.sh Script${NC}"
ssh pi@$DeviceIP "rm ./RaspiQtCrossCompile_PiSetup.sh"

# Set up host
echo -e "${GREEN}Updating host${NC}"
sudo apt update
#sudo apt upgrade

# Install packages
echo -e "${GREEN}Installing packages${NC}"
sudo apt-get -y install make build-essential libclang-dev ninja-build gcc git bison python3 gperf pkg-config libfontconfig1-dev libfreetype6-dev libx11-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libatspi2.0-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev build-essential gawk git texinfo bison file wget libssl-dev gdbserver gdb-multiarch libxcb-cursor-dev
# Install other ueful packages
sudo apt-get -y install ccache jq
pip install html5lib
pip3 install html5lib

# Set up install for node 20. The defualt version is 10 which is too old
curl -sL https://deb.nodesource.com/setup_20.x | sudo bash -
# Install the package
sudo apt-get -y install nodejs

# Create archives cache
if [ ! -d ${SOURCE_CACHE_LOC} ]; then
    echo -e "${GREEN}Creating source cache folder${NC}"
    mkdir -p ${SOURCE_CACHE_LOC}
fi

# Build CMake
cd ~/RaspberryPiQtCrossCompiler
./RaspiQtCrossCompile_BuildCMake.sh "$BUILD_LOC" $SOURCE_CACHE_LOC

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
cd ~/RaspberryPiQtCrossCompiler
./RaspiQtCrossCompile_BuildGccV2.sh "$BUILD_LOC" $SOURCE_CACHE_LOC

if [ $? -eq 0 ]
then
    echo -e "${GREEN}GCC build Successful${NC}"
else
    echo -e "${RED}GCC Build Failed${NC}"
    exit 1
fi

# Make directories
cd ${BUILD_LOC}
mkdir rpi-sysroot rpi-sysroot/usr rpi-sysroot/opt
mkdir qt6 qt6/host qt6/pi qt6/host-build qt6/pi-build qt6/src

# Download Qt source
echo -e "${GREEN}Downloading Qt Source${NC}"
cd ${SOURCE_CACHE_LOC}
if [ ! -f qt-everywhere-src-${QtVersion}.tar.xz ]; then
    wget https://download.qt.io/official_releases/qt/${QtMajorVersion}.${QtMinorVersion}/${QtVersion}/single/qt-everywhere-src-${QtVersion}.tar.xz
fi
cd ${BUILD_LOC}/qt6/src/
tar xf ${SOURCE_CACHE_LOC}/qt-everywhere-src-${QtVersion}.tar.xz 

# Build Qt for host
echo -e "${GREEN}Building Qt for Host${NC}"
cd ~/RaspberryPiQtCrossCompiler
./RaspiQtCrossCompile_QtHostBuild.sh $QtMajorVersion $QtMinorVersion $QtPatchVersion $BUILD_LOC

# Make sure success
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully built qt for host device${NC}"
else
    echo -e "${RED}Failed to build qt for host device${NC}"
    exit 1
fi

cd ~/RaspberryPiQtCrossCompiler
./RaspiQtCrossCompile_BuildQtForRaspi.sh $DeviceIP $QtMajorVersion $QtMinorVersion $QtPatchVersion $BUILD_LOC
