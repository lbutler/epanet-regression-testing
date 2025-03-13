#!/bin/bash
set -e  # Exit on error

echo "INFO: Starting EPANET regression test inside Docker."
echo "INFO: REF_TAG=${REF_TAG}, SUT_TAG=${SUT_TAG}"

#----------------------------------
# 1) Clone EPANET Repo Twice
#----------------------------------
mkdir -p /epanet/ref /epanet/sut

# --- Reference clone (v2.2 by default)
cd /epanet/ref
if [ ! -d .git ]; then
  echo "INFO: Cloning EPANET (ref) from GitHub at tag ${REF_TAG}..."
  git clone --depth=1 --branch "${REF_TAG}" https://github.com/OpenWaterAnalytics/EPANET.git .
else
  echo "INFO: Updating existing EPANET (ref) repo..."
  git fetch --all
  git checkout "${REF_TAG}"
  git pull
fi

# --- SUT clone (master or user-specified commit)
cd /epanet/sut
if [ ! -d .git ]; then
  echo "INFO: Cloning EPANET (SUT) from GitHub at tag ${SUT_TAG}..."
  git clone --depth=1 --branch "${SUT_TAG}" https://github.com/OpenWaterAnalytics/EPANET.git .
else
  echo "INFO: Updating existing EPANET (SUT) repo..."
  git fetch --all
  git checkout "${SUT_TAG}"
  git pull
fi

#----------------------------------
# 2) Build Each Version
#----------------------------------
build_epanet() {
  local build_dir="$1/build"
  local src_dir="$1"
  local label="$2"

  echo "INFO: Building EPANET in $build_dir ($label)..."
  mkdir -p "$build_dir"
  cd "$build_dir"
  cmake -DBUILD_TESTS=ON "$src_dir"
  make -j$(nproc)

  # Run unit tests
  echo "INFO: Running unit tests for $label..."
  cd tests
  ctest -C Release --output-on-failure
  cd "$src_dir"
}

build_epanet "/epanet/ref" "Reference Build"
build_epanet "/epanet/sut" "SUT Build"

#----------------------------------
# 3) Download standard test suite (if DO_STANDARD_TEST=true)
#----------------------------------
if [ "$DO_STANDARD_TEST" = "true" ]; then
  echo "INFO: Downloading official EPANET example networks for standard tests..."
  mkdir -p "$TEST_HOME"
  cd "$TEST_HOME"
  rm -rf ./*

  LATEST_URL="${EXAMPLES_REPO}/releases/latest"
  LATEST_TAG=$(curl -sI "$LATEST_URL" | grep -Po 'tag\/\K(v\S+)' || true)
  if [ -z "$LATEST_TAG" ]; then
    echo "WARNING: Could not retrieve the latest tag for example networks. Using master."
    LATEST_TAG="master"
  fi

  ARCHIVE_URL="https://codeload.github.com/OpenWaterAnalytics/epanet-example-networks/tar.gz/${LATEST_TAG}"
  echo "INFO: Downloading $ARCHIVE_URL ..."
  curl -fsSL -o examples.tar.gz "$ARCHIVE_URL"
  tar xzf examples.tar.gz && rm examples.tar.gz

  BASENAME="epanet-example-networks-${LATEST_TAG#v}"
  if [ ! -d "$BASENAME" ]; then
    echo "ERROR: Could not find extracted folder $BASENAME"
    ls -l
    exit 1
  fi

  # Link epanet-tests to a "tests" folder
  ln -s "${BASENAME}/epanet-tests" tests
fi

#----------------------------------
# 4) nrtest "app config" JSON for each version
#----------------------------------
mkdir -p "$TEST_HOME/apps"

ref_app="$TEST_HOME/apps/epanet-ref.json"
cat <<EOF > "$ref_app"
{
  "name" : "epanet-ref",
  "version" : "unknown",
  "description" : "${PLATFORM} reference",
  "setup_script" : "",
  "exe" : "/epanet/ref/build/bin/runepanet"
}
EOF

sut_app="$TEST_HOME/apps/epanet-sut.json"
cat <<EOF > "$sut_app"
{
  "name" : "epanet-sut",
  "version" : "unknown",
  "description" : "${PLATFORM} SUT",
  "setup_script" : "",
  "exe" : "/epanet/sut/build/bin/runepanet"
}
EOF

#----------------------------------
# 5) Run nrtest execute for each (if DO_STANDARD_TEST=true)
#----------------------------------
if [ "$DO_STANDARD_TEST" = "true" ]; then
  echo "INFO: Running nrtest on standard tests..."
  cd "$TEST_HOME"

  TEST_FILES=$(ls -1 ./tests/*/*.json)
  if [ -z "$TEST_FILES" ]; then
    echo "WARNING: No test JSON files found! Standard tests skipped."
  else
    # REF results
    nrtest execute "$ref_app"  $TEST_FILES -o ./benchmark/epanet-ref
    # SUT results
    nrtest execute "$sut_app"  $TEST_FILES -o ./benchmark/epanet-sut

    # Compare
    echo "INFO: Comparing epanet-sut to epanet-ref..."
    nrtest compare ./benchmark/epanet-sut ./benchmark/epanet-ref --rtol 0.01 --atol 1e-6
  fi
else
  echo "INFO: Skipping standard tests per DO_STANDARD_TEST=false."
fi

#----------------------------------
# 6) Optional custom tests (if DO_CUSTOM_TEST=true)
#----------------------------------
if [ "$DO_CUSTOM_TEST" = "true" ]; then
  if [ -d "/custom_tests" ]; then
    echo "INFO: Found /custom_tests. Executing nrtest..."
    mkdir -p "$TEST_HOME/benchmark"
    nrtest execute "$sut_app" /custom_tests -o "$TEST_HOME/benchmark/custom_sut" || true

    # Optionally compare custom_sut to custom_ref if you want
    # ...
  else
    echo "INFO: DO_CUSTOM_TEST=true but no /custom_tests directory found."
  fi
fi

echo "INFO: EPANET regression test completed successfully."
