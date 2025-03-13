# Use Ubuntu as the base
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

# Working directory
WORKDIR /epanet

# Copy "nrtest-epanet" folder so we can install the plugin
COPY nrtest-epanet /nrtest-epanet/
RUN pip3 install /nrtest-epanet/

# Copy Python requirements for nrtest, epanet.output, etc.
COPY requirements-epanet.txt /tmp/requirements-epanet.txt
RUN pip3 install -r /tmp/requirements-epanet.txt

# Environment variables for controlling build & testing
ENV REF_TAG="v2.2" \
    SUT_TAG="master" \
    DO_STANDARD_TEST="true" \
    DO_CUSTOM_TEST="false" \
    EXAMPLES_REPO="https://github.com/OpenWaterAnalytics/epanet-example-networks" \
    BUILD_HOME="/epanet/build" \
    TEST_HOME="/epanet/nrtests" \
    PLATFORM="linux"

# Copy the new entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]
