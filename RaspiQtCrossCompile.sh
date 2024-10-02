#!/bin/bash

# Track the initial location b/c this is where the scripts are at
origDir=$PWD

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'  # Blue
NC='\033[0m' # No Color

# The script now uses a configuration file to set settings. If not present
# then exit
if [[ ! -f build.conf ]]; then
    echo -e "${RED}Failed to find build.conf. Unable to proceed${NC}"
    exit 1
fi

# Read in settings from the configuration file
while IFS= read -r line; do
    # echo $line
    # Skip lines that are empty or start with '#'
    if [[ $line == "#"* ]]; then
       # echo "Skipping comment: "$line
        continue
    elif [[ -z $line ]]; then
        #echo "Skipping empty line"
        continue
    fi

    # Split the line into sections based on '='
    IFS='=' read -r -a array <<< "$line"

    # Make sure the array has exactly 2 items
    if [ ${#array[@]} -ne 2 ]; then
        echo -e "${RED}Invalid line: '${line}'. Expects 2 items received: ${#array[@]}${NC}"
        exit 1
    fi

    echo -e "${BLUE} Setting variable: ${array[0]}=${array[1]}${NC}"
    declare ${array[0]}=${array[1]}

done < build.conf

# Split the Qt version string into sections
if [[ -z $QtVersion ]]; then
    echo -e "${RED}Required variable QtVersion is null${NC}"
    exit 1
fi
IFS='.' read -r -a array <<< "${QtVersion}"
if [ ${#array[@]} -ne 3 ]; then
    echo -e "${RED}Received invalid QtVersion string: ${QtVersion}${NC}"
    exit 1
fi
QtMajorVersion=${array[0]}
QtMinorVersion=${array[1]}
QtPatchVersion=${array[2]}
QtVersion="${QtMajorVersion}.${QtMinorVersion}.${QtPatchVersion}"

# The base path determines where the build will be placed: Ex: /home/tommy/Qt_6_6_2
# If the base path was not set using the conf file, generate it
if test -z $basePath; then
    basePath=$HOME/Qt_${QtMajorVersion}_${QtMinorVersion}_${QtPatchVersion}
fi

# Log that starting script
echo -e "${GREEN}Starting Cross Compile Qt${NC}"
echo -e "Qt Version: ${QtVersion}"
echo -e "Build Loc: ${basePath}"


# Get number of threads
echo -e "${GREEN}Getting number of threads${NC}"
threads=$(nproc)
threads=$(( $threads + 3 ))
echo -e "${GREEN}Using $threads Threads${NC}"

# Try to create the build dir
echo -e "${Green}Creating build dir:${BLUE}${basePath}${NC}"
mkdir -p $basePath
if [ $? -eq 0 ]
then
    echo -e "${GREEN}Successfully created build loc${NC}"
else
    echo -e "${RED}Failed to create build loc${NC}"
    exit 1
fi

# Create archives cache
if [ ! -d ${SOURCE_CACHE_LOC} ]; then
    echo -e "${GREEN}Creating source cache folder:${NC} ${SOURCE_CACHE_LOC}"
    mkdir -p ${SOURCE_CACHE_LOC}
fi

# Create the build dirs
mkdir -p ${basePath}/host
mkdir -p ${basePath}/host-build
mkdir -p ${basePath}/${buildLabel}
mkdir -p ${basePath}/${buildLabel}-build

# If configured to work with a device, set up the device
if [[ $interactsWithDevice -eq 1 ]]; then
    echo -e "${GREEN}Configuring device${NC}"
    echo -e "Target Device IP: ${DeviceIP}"

    # Make the sys root folders
    mkdir -p ${basePath}/${buildLabel}-sysroot
    mkdir -p ${basePath}/${buildLabel}-sysroot/usr
    mkdir -p ${basePath}/${buildLabel}-sysroot/opt

    # Check if the raspberry pi is online
    echo -e "${GREEN}Checking if Raspberry Pi is online: ${deviceIP}${NC}"
    if ping -c 1 $deviceIP &> /dev/null
    then
        echo -e "${GREEN}Raspberry Pi is online${NC}"
    else
        echo -e "${RED}Raspberry Pi is offline${NC}"
        exit
    fi

    # Copy ssh key to the target device
    echo -e "${GREEN}Copying SSH Key${NC}"
    ssh-copy-id $account@$deviceIP

    # Copy the PiSetup.sh script to the target device
    echo -e "${GREEN}Copying PiSetup.sh Script${NC}"
    scp RaspiQtCrossCompile_PiSetup.sh $account@$deviceIP:~/

    # Run the PiSetup.sh script
    echo -e "${GREEN}Running PiSetup.sh Script${NC}"
    ssh $account@$deviceIP ./RaspiQtCrossCompile_PiSetup.sh

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

    # Copy the sys root from the device
    echo -e "${GREEN}Copying Sysroot${NC}"

    # Move to the directory that will hold the sysroot
    cd ${basePath}/

    # Copy the sysroo from the target device
    rsync -avz --info=progress2 --copy-unsafe-links --rsync-path="sudo rsync" --delete $account@$deviceIP:/usr ${buildLabel}-sysroot

    rm ${buildLabel}-sysroot/lib/aarch64-linux-gnu/libQt*

    # Move into the sys root
    cd ${buildLabel}-sysroot
    # Make the lib symlink
    ln -s usr/lib lib

    # Return to the start diectory
    cd $origDir
else
    if [ ! -d ${basePath}/${buildLabel}-sysroot ]; then
        ln -s $sysrootLoc ${basePath}/${buildLabel}-sysroot
    fi
fi

# Make sure that the source cache is loaded
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
        echo -e "Unpacking Qt Source"
        tar xf qt-everywhere-src-$4.tar.xz 
    fi
}
# Download Qt source
echo -e "${GREEN}Downloading Qt Source${NC}"
download_qt_src ${SOURCE_CACHE_LOC} $QtMajorVersion $QtMinorVersion $QtVersion

# Set up host
echo -e "${GREEN}Updating host${NC}"
apt update

# Install packages
echo -e "${GREEN}Installing packages${NC}"
DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get install -y tzdata
apt-get -y install make build-essential libclang-dev ninja-build gcc git bison python3 gperf pkg-config libfontconfig1-dev libfreetype6-dev libx11-dev libx11-xcb-dev libxext-dev libxfixes-dev libxi-dev libxrender-dev libxcb1-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-image0-dev libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libatspi2.0-dev libgl1-mesa-dev libglu1-mesa-dev freeglut3-dev build-essential gawk git texinfo bison file wget libssl-dev gdbserver gdb-multiarch libxcb-cursor-dev
# Install other ueful packages
apt-get -y install ccache jq
apt-get -y install python3-html5lib

# Set up install for node 20. The defualt version is 10 which is too old
curl -sL https://deb.nodesource.com/setup_20.x | bash -
# Install the package
apt-get -y install nodejs

# Build CMake
echo -e "${GREEN}Starting CMake build${NC}"
cd $origDir
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
cd $origDir
./RaspiQtCrossCompile_BuildGccV2.sh "$basePath" $SOURCE_CACHE_LOC

if [ $? -eq 0 ]
then
    echo -e "${GREEN}GCC build Successful${NC}"
else
    echo -e "${RED}GCC Build Failed${NC}"
    exit 1
fi

# Ihe host build is already complete, skip it
if [ -f $basePath/host/bin/qmake ]; then
    echo -e "${GREEN}The host build already exists. Skipping${NC}"
else
    # Build Qt for host
    echo -e "${GREEN}Building Qt for Host${NC}"
    cd $origDir
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
    cd $origDir
    ./RaspiQtCrossCompile_BuildQtForRaspi.sh $deviceIP $QtMajorVersion $QtMinorVersion $QtPatchVersion $basePath $account $SOURCE_CACHE_LOC $buildLabel
fi
