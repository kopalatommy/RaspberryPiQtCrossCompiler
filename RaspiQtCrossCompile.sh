#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Varialbes used by the script
# DeviceIP, the ip address of the target raspberry pi
DeviceIP="192.168.1.133"
export DeviceIP="192.168.1.133"

account=orangepi

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

# The base path determines where the build will be placed: /home/tommy/Qt_6_6_2
basePath=$HOME/Qt_${QtMajorVersion}_${QtMinorVersion}_${QtPatchVersion}

# Build label, use this to distinquish between multiple cross compiles. For example, pi4, pi5, aarch64, armhf, orangepi, etc
buildLabel=$1

# This is a cache of sources. This is useful if building a cross compiler for multiple different configurations. It is kept separate from the base dir
# incase compiling multiple versions of Qt
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
echo -e "Build Loc: ${basePath}"

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
echo -e "${Green}Creating build dir:${BLUE}${basePath}${NC}"
mkdir -p $basePath
if [ $? -eq 0 ]
then
    echo -e "${GREEN}Successfully created build loc${NC}"
else
    echo -e "${RED}Failed to create build loc${NC}"
    exit 1
fi

# Copy ssh key to the target device
echo -e "${GREEN}Copying SSH Key${NC}"
ssh-copy-id $account@$DeviceIP

# Get number of threads
echo -e "${GREEN}Getting number of threads${NC}"
threads=$(nproc)
export threads=$(nproc)
echo -e "${GREEN}Using $threads Threads${NC}"

# Copy the PiSetup.sh script to the target device
echo -e "${GREEN}Copying PiSetup.sh Script${NC}"
scp RaspiQtCrossCompile_PiSetup.sh $account@$DeviceIP:~/

# Run the PiSetup.sh script
echo -e "${GREEN}Running PiSetup.sh Script${NC}"
ssh $account@$DeviceIP ./RaspiQtCrossCompile_PiSetup.sh

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
ssh $account@$DeviceIP "rm ./RaspiQtCrossCompile_PiSetup.sh"

# Set up host
echo -e "${GREEN}Updating host${NC}"
sudo apt update
#sudo apt upgrade

# Install packages
echo -e "${GREEN}Installing packages${NC}"
sudo apt-get -y install make build-essential libclang-dev ninja-build gcc git bison python3 gperf pkg-config libfontconfig1-dev libfreetype6-dev libx11-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libatspi2.0-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev build-essential gawk git texinfo bison file wget libssl-dev gdbserver gdb-multiarch libxcb-cursor-dev
# Install other ueful packages
sudo apt-get -y install ccache jq
sudo apt-get -y install python3-html5lib

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
./RaspiQtCrossCompile_BuildCMake.sh "$basePath" $SOURCE_CACHE_LOC

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
./RaspiQtCrossCompile_BuildGccV2.sh "$basePath" $SOURCE_CACHE_LOC

if [ $? -eq 0 ]
then
    echo -e "${GREEN}GCC build Successful${NC}"
else
    echo -e "${RED}GCC Build Failed${NC}"
    exit 1
fi

make_directories () {
    # Make directories
    cd $1

    # Make the host path if not already built
    if [ ! -f host/bin/qmake ]; then
        mkdir host
        mkdir host-build
    fi

    # Make the dirs for the configuration
    if [ ! -f $2/bin/qmake ]; then
        mkdir $2
        mkdir $2-build
    fi

    if [ ! -d $2-sysroot ]; then
        mkdir $2-sysroot
        mkdir $2-sysroot/usr
        mkdir $2-sysroot/opt
    fi
}
make_directories $basePath

# This function handles downloading and extracting the qt source files if not already downloaded
# Args:
# 1 - src path
# 2 - qt major version
# 3 - qt minor version
# 4 - qt version
download_qt_src () {
    cd $1

    # If the source archive doesn't exist, download it
    if [ ! -f qt-everywhere-src-$4.tar.xz ]; then
        wget https://download.qt.io/official_releases/qt/$2.$3/$4/single/qt-everywhere-src-$4.tar.xz
    fi

    # If the archive hasn't been extracted, extract it
    if [ ! -d qt-everywhere-src-$4 ]; then
        tar xf qt-everywhere-src-$4.tar.xz 
    fi
}
# Download Qt source
echo -e "${GREEN}Downloading Qt Source${NC}"
download_qt_src ${SOURCE_CACHE_LOC} $QtMajorVersion $QtMinorVersion $QtVersion

# Ihe host build is already complete, skip it
if [ -f $basePath/host/bin/qmake ]; then
    echo "${GREEN}The host build already exists. Skipping${NC}"
else
    # Build Qt for host
    echo -e "${GREEN}Building Qt for Host${NC}"
    cd ~/RaspberryPiQtCrossCompiler
    ./RaspiQtCrossCompile_QtHostBuild.sh $QtMajorVersion $QtMinorVersion $QtPatchVersion $basePath $SOURCE_CACHE_LOC

    # Make sure success
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully built qt for host device${NC}"
    else
        echo -e "${RED}Failed to build qt for host device${NC}"
        exit 1
    fi
fi

# If the target build is already complete, skip it
if [ -f $basePath/$buildLabel/bin/qmake ]; then
    echo "${GREEN}The target build already exists. SKipping${NC}"
else
    cd ~/RaspberryPiQtCrossCompiler
    ./RaspiQtCrossCompile_BuildQtForRaspi.sh $DeviceIP $QtMajorVersion $QtMinorVersion $QtPatchVersion $basePath $account $SOURCE_CACHE_LOC $buildLabel
fi


