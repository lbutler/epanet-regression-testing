# Use Ubuntu as the base image
FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
  git \
  curl \
  python3 \
  python3-pip \
  cmake \
  build-essential \
  p7zip-full \
  tar \
  unzip \
  jq \
  libboost-all-dev 

# Set up a working directory
WORKDIR /epanet

# Copy the entire nrtest-epanet folder into the container
COPY nrtest-epanet /nrtest-epanet/
RUN pip3 install /nrtest-epanet/

# Copy Python requirements
COPY requirements-epanet.txt /tmp/requirements-epanet.txt

# Install Python dependencies (nrtest, nrtest-epanet, etc.)
RUN pip3 install -r /tmp/requirements-epanet.txt

# Set environment variables for your build
# Add REF_BUILD_ID=2.2 if you want to run the reference comparison by default
ENV PROJECT=epanet \
    BUILD_HOME=/epanet/build \
    TEST_HOME=/epanet/nrtests \
    EPANET_REPO="https://github.com/OpenWaterAnalytics/EPANET.git" \
    EXAMPLES_REPO="https://github.com/OpenWaterAnalytics/epanet-example-networks" \
    SUT_BUILD_ID=local \
    REF_BUILD_ID=unknown \
    PLATFORM=linux

# Copy our entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /epanet

ENTRYPOINT ["/entrypoint.sh"]
