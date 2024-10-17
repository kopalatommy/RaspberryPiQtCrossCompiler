# Use the ubuntu base image
FROM ubuntu:latest
# Make sure it is upto date
RUN apt update && apt install -y git curl rsync wget xz-utils
# Get the command line argument deviceLabel. Ex) deviceLabel=RaspberryPI5
ARG deviceLabel
# Clone the build scripts
RUN git clone --branch Version2_Development https://github.com/kopalatommy/RaspberryPiQtCrossCompiler
# Move to the cloned directory
WORKDIR /RaspberryPiQtCrossCompiler
# Make sure the correct version is selected
#RUN git checkout Version2_Development
# Copy the build configuration file
COPY build.conf build.conf
# Copy the sysroot to the container
COPY ${deviceLabel}-sysroot ${deviceLabel}-sysroot
# Build the cross compiler
RUN ./RaspiQtCrossCompile.sh
# Delete the source archive
RUN rm -rf /QtCrossSourceCache