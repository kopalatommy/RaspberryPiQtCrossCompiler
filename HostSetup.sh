DEVICE=linux-rasp-pi4-v3d-g++
IP=192.168.1.128
CORES=$(nproc)
DIRECTORY=/opt/RaspberryQt4
# Location where the cross compiler and sysroot are stored
COMPILER_PATH=/opt/RaspberryQt4
QT_VER=5.15
QT_SUB_VER=${QT_VER}.2
# Directory where the cross compiled qt binaries will be placed
PI_LOC=/usr/local/RaspberryQt4
# Directory where the cross compiler will be installed
COMP_LOC=$HOME/CrossCompilers/${DEVICE}/${QT_SUB_VER}

Red="\033[0;31m"
Green="\033[0;32m"
Reset="\033[0m"
Yellow="\033[0;33m"
Cyan="\033[0;36m"

# Can check if configuration was a success by checking config.summary in build dir 

optstring="d:i:v:c:"
while getopts ${optstring} arg; do
  case ${arg} in
	d)
		SKIP_DEVICE=1
		DEVICE=${OPTARG};;
	i)
		SKIP_IP=1
		IP=${OPTARG};;
	v)
		SKIP_VER=1
		QT_SUB_VER=${OPTARG}
		IFS='.'
		read -ra SPLIT <<< "${QT_SUB_VER}"
		QT_VER="${SPLIT[0]}.${SPLIT[1]}"
		IFS=' ';;
	c)
		SKIP_COMPILER=1
		COMPILER_PATH=${OPTARG};;
	?)
		echo "Invalid option: -${OPTARG}."
		exit 1;;
	esac
done

echo "Current device: ${DEVICE}"

if [ ${SKIP_DEVICE} != 1 ]
then
	read -p "Change device(Y/n)? " NEW_DEV

	if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
	then
		echo "1 - linux-rasp-pi-g++"
		echo "2 - linux-rasp-pi2-g++"
		echo "3 - linux-rasp-pi3-g++"
		echo "4 - linux-rasp-pi3-vc4-g++"
		echo "5 - linux-rasp-pi4-v3d-g++"

		read -p "Enter device number: " NEW_DEV

		if [[ ${NEW_DEV} == "1" ]]
		then
			DEVICE=linux-rasp-pi-g++
		elif [[ ${NEW_DEV} == "2" ]]
		then
			DEVICE=linux-rasp-pi2-g++
		elif [[ ${NEW_DEV} == "3" ]]
		then
			DEVICE=linux-rasp-pi3-g++
		elif [[ ${NEW_DEV} == "4" ]]
		then
			DEVICE=linux-rasp-pi3-vc4-g++
		elif [[ ${NEW_DEV} == "5" ]]
		then
			DEVICE=linux-rasp-pi4-v3d-g++
		else
			echo "Entered invalid option: ${NEW_DEV}"
			exit 1
		fi
	fi
fi
echo "Building for ${DEVICE}"

if [[ ${SKIP_IP} != 1 ]]
then
	echo "Device IP Address: ${IP}"
	read -p "Change ip address(Y/n)? " NEW_DEV
	if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
	then
		read -p "Enter IP: " IP
	fi
fi

echo "Device IP Address: ${IP}"
eval "ping -c 1 ${IP}"

if [[ $? != 0 ]]
then
	echo "Failed to ping device. Check that both the PC and the PI are on the same network"
	exit 1
fi

if [[ ${SKIP_VER} != 1 ]]
then
	echo "Currenly building Qt: ${QT_SUB_VER}"
	read -p "Change Qt version(Y/n)? " NEW_DEV
	if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
	then
		read -p "Enter new version: " QT_SUB_VER
		IFS='.'
		read -ra SPLIT <<< "${QT_SUB_VER}"
		QT_VER="${SPLIT[0]}.${SPLIT[1]}"
		IFS=' '
	fi
fi

echo "Building QT: ${QT_SUB_VER}"

echo -e ${Yellow}"Setting up remote conn..."${Reset}
# Check if the user has ssh keys present
if [[ ! -f ~/.ssh/rpi_pi_id_rsa ]]
then
	echo -e ${Yellow}"Generate SSH keys..."${Reset}
	ssh-keygen -t rsa -C pi@${IP} -P "" -f ~/.ssh/rpi_pi_id_rsa
else
	echo -e ${Yellow}"Adding SSH key to pi..."${Reset}
	ssh-copy-id pi@${IP}
fi
cat ~/.ssh/rpi_pi_id_rsa.pub | ssh pi@${IP} 'cat >> .ssh/authorized_keys && chmod 640 .ssh/authorized_keys'


echo -e ${Yellow}"Setting up compiler..."${Reset}

echo -e ${Cyan}"Compiler path: "${Reset}${COMPILER_PATH}
read -p "Change compiler path(Y/n)? " NEW_DEV
if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
then
	read -p "New compiler path: " COMPILER_PATH
fi
echo -e ${Cyan}"Compiler path: "${Reset}${COMPILER_PATH}

sudo mkdir -p ${COMPILER_PATH} ${COMPILER_PATH}/sysroot ${COMPILER_PATH}/sysroot/usr ${COMPILER_PATH}/sysroot/opt
sudo chown -R $USER ${COMPILER_PATH}
if [[ ${SKIP_COMPILER} != 1 ]]
then
	echo "Select Cross Compiler:"
	echo "1 - Compile /opt/cross-pi-gcc/bin/arm-linux-gnueabihf-"
	echo "2 - https://github.com/raspberrypi/tools"
	echo "3 - gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf"

	read -p "Choose Cross Compiler: " COM_CHOICE

	case $COM_CHOICE in
	"1")
		echo -e ${Yellow}"Cross compiling GCC 10.1.0"${Reset}

		# If the cross compiler has already been built, do not rebuild it
		if [[ ! -f ${COMPILER_PATH}/cross-pi-gcc ]]
		then
			./BuildCrossCompiler.sh -i ${IP} -c ${COMPILER_PATH}
		else
			echo -e ${Green}"Cross compiled GCC 10.1.0 already exists. Using existing tools"${Reset}
		fi
		COMPILER_LOC=${COMPILER_PATH}/cross-pi-gcc/bin/arm-linux-gnueabihf-
		;;
	"2")
		echo "Getting https://github.com/raspberrypi/tools"
		cd ${COMPILER_PATH}

		if [[ ! -f tools/ ]]
		then
			git clone https://github.com/raspberrypi/tools
		else
			echo -e ${Green}"Tools folder already exists. Using existing tools."${Reset}
		fi
		COMPILER_LOC=${COMPILER_PATH}/tools/arm-bcm2708/gcc-linaro-arm-linux-gnueabihf-raspbian-x64/bin/arm-linux-gnueabihf-
		;;
	"3")
		cd ${COMPILER_PATH}

		echo "Getting wget https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz"

		if [[ ! -f gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/ ]]
		then
			wget https://releases.linaro.org/components/toolchain/binaries/latest-7/arm-linux-gnueabihf/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz
			tar xf gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf.tar.xz
			# ToDo, test if this works. Might need to be set differently
			export PATH=$PATH:${COMPILER_PATH}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin
			echo "export PATH=$PATH:${COMPILER_PATH}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin" >> ~/.bashrc
		else
			echo -e ${Green}"Linaro toolchain already copied. Using existing."${Reset}
		fi
		COMPILER_LOC=${COMPILER_PATH}/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-
		;;
	?)
		echo "Invalid compiler choice: ${COM_CHOICE}"
		exit 1
	esac
fi

echo -e ${Cyan}"Build directory: "${Reset}${DIRECTORY}
read -p "Change build directory(Y/n)? " NEW_DEV
if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
then
	read -p "New compiler path: " DIRECTORY
fi
echo -e ${Cyan}"Build directory: "${Reset}${DIRECTORY}

sudo mkdir -p ${DIRECTORY}
sudo chown -R $USER ${DIRECTORY}

cd ${DIRECTORY}

echo -e ${Yellow}"Setting up pi..."${Reset}
scp ~/CrossCompiler/RaspSetup.sh pi@${IP}:~
ssh pi@${IP} "/home/pi/RaspSetup.sh"

echo -e ${Yellow}"Install packages..."${Reset}
sudo apt-get update
sudo apt-get -y install gcc git bison python gperf pkg-config gdb-multiarch qt5-default

echo -e ${Yellow}"Create directories..."${Reset}
if [[ ! -d ~/CrossCompilers ]]
then
sudo mkdir -p ~/CrossCompilers
fi
if [[ ! -d ~/CrossCompilers/${DEVICE} ]]
then
sudo mkdir -p ~/CrossCompilers/${DEVICE}
fi
if [[ ! -d ~/CrossCompilers/${DEVICE}/${QT_SUB_VER} ]]
then
sudo mkdir -p ~/CrossCompilers/${DEVICE}/${QT_SUB_VER}
fi
sudo mkdir -p ${DIRECTORY}/log ${DIRECTORY}/build
sudo mkdir -p ${COMPILER_PATH}/sysroot ${COMPILER_PATH}/sysroot/usr ${COMPILER_PATH}/sysroot/opt

sudo chown -R $USER ~/CrossCompilers

cd ${DIRECTORY}
sudo chown -R 1000:1000 ${DIRECTORY}
sudo chown -R 1000:1000 ${COMPILER_PATH}

echo -e ${Yellow}"Download Qt..."${Reset}
wget https://download.qt.io/archive/qt/${QT_VER}/${QT_SUB_VER}/single/qt-everywhere-src-${QT_SUB_VER}.tar.xz

echo -e ${Yellow}"Download Python script..."${Reset}
wget https://raw.githubusercontent.com/riscv/riscv-poky/master/scripts/sysroot-relativelinks.py
sudo chmod +x sysroot-relativelinks.py

tar xf qt-everywhere-src-${QT_SUB_VER}.tar.xz
cp -R qt-everywhere-src-${QT_SUB_VER}/qtbase/mkspecs/linux-arm-gnueabi-g++ qt-everywhere-src-${QT_SUB_VER}/qtbase/mkspecs/linux-arm-gnueabihf-g++
sed -i -e 's/arm-linux-gnueabi-/arm-linux-gnueabihf-/g' qt-everywhere-src-${QT_SUB_VER}/qtbase/mkspecs/linux-arm-gnueabihf-g++/qmake.conf

cd ${COMPILER_PATH}

# rsync will fail to grab all files the first few times. Run this section a few times to make sure all files are grabbed
# If some files are missing, the configure tests will fail
for VARIABLE in {1..5}
do
	echo -e ${Yellow}"Download /lib"${Reset}
	rsync -avz --rsync-path="sudo rsync" pi@${IP}:/lib sysroot | tee ${DIRECTORY}/log/copy_lib.log
	echo -e ${Yellow}"Download /usr/include"${Reset}
	rsync -avz --rsync-path="sudo rsync" pi@${IP}:/usr/include sysroot/usr | tee ${DIRECTORY}/log/copy_usr_include.log
	echo -e ${Yellow}"Download /usr/lib"${Reset}
	rsync -avz --rsync-path="sudo rsync" pi@${IP}:/usr/lib sysroot/usr | tee ${DIRECTORY}/log/copy_usr_lib.log
	echo -e ${Yellow}"Download /opt/vc"${Reset}
	rsync -avz --rsync-path="sudo rsync" pi@${IP}:/opt/vc sysroot/opt | tee ${DIRECTORY}/log/copy_opt_vc.log
done

echo -e ${Yellow}"Changing symlinks"${Reset}
unlink sysroot/usr/lib/arm-linux-gnueabihf/libEGL.so.1.0.0
ln -s sysroot/opt/vc/lib/libEGL.so sysroot/usr/lib/arm-linux-gnueabihf/libEGL.so.1.0.0
unlink sysroot/usr/lib/arm-linux-gnueabihf/libGLESv2.so.2.0.0
ln -s sysroot/opt/vc/lib/libGLESv2.so sysroot/usr/lib/arm-linux-gnueabihf/libGLESv2.so.2.0.0
unlink sysroot/opt/vc/lib/libEGL.so.1
ln -s sysroot/opt/vc/lib/libEGL.so sysroot/opt/vc/lib/libEGL.so.1
unlink sysroot/opt/vc/lib/libGLESv2.so.2
ln -s sysroot/opt/vc/lib/libGLESv2.so sysroot/opt/vc/lib/libGLESv2.so.2
${DIRECTORY}/sysroot-relativelinks.py sysroot

echo -e ${Yellow}"Configuring Qt..."${Reset}
cd ${DIRECTORY}/build
../qt-everywhere-src-${QT_SUB_VER}/configure -release -opengl es2 -eglfs -device ${DEVICE} -device-option CROSS_COMPILE=${COMPILER_LOC} -sysroot ${COMPILER_PATH}/sysroot -prefix ${PI_LOC} -extprefix ~/CrossCompilers/${DEVICE}/${QT_SUB_VER} -opensource -confirm-license -skip qtscript -skip qtwebengine -nomake tests -make libs -pkg-config -no-use-gold-linker -v -recheck | tee ${DIRECTORY}/log/config.log

echo -e ${Yellow}"Building Qt"${Reset}
make -j${CORES} | tee ${DIRECTORY}/log/make.log
make install | tee ${DIRECTORY}/log/install.log

echo -e ${Yellow}"Copying Qt binaries to pi"${Reset}
rsync --rsync-path="sudo rsync" -avz ~/CrossCompilers/${DEVICE}/${QT_SUB_VER}/ pi@${IP}:${PI_LOC} | tee ${DIRECTORY}/log/copy_RaspberryQt.log

read -p "Clean up build files?(Y/n) " Clean

if [ ${NEW_DEV} == "Y" ] || [ ${NEW_DEV} == "y" ] || [ ${NEW_DEV} == "\n" ]
then
	echo -e ${Yellow}"Cleaning build files"${Reset}
	sudo rm -r ${DIRECTORY}/build
	sudo rm -r ${DIRECTORY}/sysroot-relativelinks.py
	sudo rm -r ${DIRECTORY}/qt-everywhere-src-${QT_SUB_VER}
	sudo rm ${DIRECTORY}/qt-everywhere-src-${QT_SUB_VER}.tar.xz
else
	echo -e ${Yellow}"Leftover files:"${Reset}
	echo "${DIRECTORY}/build"
	echo "${DIRECTORY}/sysroot-relativelinks.py"
	echo "${DIRECTORY}/qt-everywhere-src-${QT_SUB_VER}"
	echo "${DIRECTORY}/qt-everywhere-src-${QT_SUB_VER}.tar.xz"
fi

