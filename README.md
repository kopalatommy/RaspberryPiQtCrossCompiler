# RaspberryPiQtCrossCompiler
This repo holds bash scripts that automate the process of building Qt for the Raspberry Pi

# Notes
This was tested on a Debian image running on wsl2. This successfully cross compiled Qt 5.15.2 for the Raspberry Pi 4

# Possible Errors
1. If the configuration tests fail, manually run the rsync lines until no new files are obtained.
2. If everything succeeds, but the executable wont run on the Pi, make sure the compiled binaries were co[pied to the proper location

