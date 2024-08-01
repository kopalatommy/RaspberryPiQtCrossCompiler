#!/bin/bash

# Values for coloring output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Get the number of threads to speed up the compilation
threads=$(nproc)

# This scipt is entended for use with the raspberry pi when building Qt 6 for the raspberry pi 5

# Log that starting the script
echo -e "${GREEN}Starting Pi setup script...${NC}"

# Update the device
echo -e "${GREEN}Updating device...${NC}"
sudo apt update
sudo apt upgrade -y

# Install the necessary packages on the raspberry pi
echo -e "${GREEN}Installing necessary packages...${NC}"
sudo apt-get install -y libboost-all-dev libudev-dev libinput-dev libts-dev libmtdev-dev libjpeg-dev libfontconfig1-dev libssl-dev libdbus-1-dev libglib2.0-dev libxkbcommon-dev libegl1-mesa-dev libgbm-dev libgles2-mesa-dev mesa-common-dev libasound2-dev libpulse-dev gstreamer1.0-omx libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev  gstreamer1.0-alsa libvpx-dev libsrtp2-dev libsnappy-dev libnss3-dev "^libxcb.*" flex bison libxslt-dev ruby gperf libbz2-dev libcups2-dev libatkmm-1.6-dev libxi6 libxcomposite1 libfreetype6-dev libicu-dev libsqlite3-dev libxslt1-dev 
sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libx11-dev freetds-dev libsqlite3-dev libpq-dev libiodbc2-dev firebird-dev libgst-dev libxext-dev libxcb1 libxcb1-dev libx11-xcb1 libx11-xcb-dev libxcb-keysyms1 libxcb-keysyms1-dev libxcb-image0 libxcb-image0-dev libxcb-shm0 libxcb-shm0-dev libxcb-icccm4 libxcb-icccm4-dev libxcb-sync1 libxcb-sync-dev libxcb-render-util0 libxcb-render-util0-dev libxcb-xfixes0-dev libxrender-dev libxcb-shape0-dev libxcb-randr0-dev libxcb-glx0-dev libxi-dev libdrm-dev libxcb-xinerama0 libxcb-xinerama0-dev libatspi2.0-dev libxcursor-dev libxcomposite-dev libxdamage-dev libxss-dev libxtst-dev libpci-dev libcap-dev libxrandr-dev libdirectfb-dev libaudio-dev libxkbcommon-x11-dev gdbserver
# Other nice packages
sudo apt-get install -y git vim htop jq ccache
sudo apt-get install -y libdouble-conversion-dev
sudo apt-get install -y python3-html5lib

# Make the installation directory
echo -e "${GREEN}Making installation directory...${NC}"
sudo mkdir /usr/local/qt6/
sudo chmod 777 /usr/local/bin/

# Check necessary build information
echo -e "${GREEN}Checking necessary build information...${NC}"
gcc --version
ld --version
ldd --version

# Add entry to .bashrc file
echo "export PATH=$PATH:/usr/local/qt6/bin/" >> ~/.bashrc
echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/qt6/lib/" >> ~/.bashrc

# Update changes
echo -e "${GREEN}Updating changes...${NC}"
source ~/.bashrc

# Exit this script
echo -e "${GREEN}Script finished.${NC}"
exit 0
