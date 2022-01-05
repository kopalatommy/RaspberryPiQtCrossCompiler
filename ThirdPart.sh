DEVICE=linux-rasp-pi4-v3d-g++
IP=192.168.1.128
CORES=$(nproc)
DIRECTORY=~/RaspberryQt
COMPILER_PATH=/opt/cross-pi-gcc
QT_VER=5.15
QT_SUB_VER=${QT_VER}.2

Red="\033[0;31m"
Green="\033[0;32m"
Reset="\033[0m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

echo -e ${Yellow}"Build Qt..."${Reset}
cd ${DIRECTORY}/build
make -j${CORES} | tee ${DIRECTORY}/log/make.log
make install | tee ${DIRECTORY}/log/install.log