#!/bin/bash

set -e  # Exit on error

echo "INFO: Starting EPANET regression test inside Docker."

# ---------------
# 1) Build EPANET with Unit Tests
# ---------------
if [ ! -d "/epanet/src" ]; then
    echo "INFO: Cloning EPANET source from $EPANET_REPO ..."
    git clone --depth=1 "$EPANET_REPO" /epanet
else
    echo "INFO: EPANET source already present. Pulling latest changes..."
    cd /epanet && git pull
fi

# Create build directory and compile
echo "INFO: Building EPANET in $BUILD_HOME with unit tests..."
mkdir -p "$BUILD_HOME"
cd "$BUILD_HOME"
cmake -DBUILD_TESTS=ON ..
make -j$(nproc)

# Run Unit Tests
echo "INFO: Running EPANET unit tests..."
cd tests
ctest -C Release --output-on-failure

# Return to EPANET directory
cd /epanet

# Path to final EPANET run executable (on Linux typically runepanet)
SUT_EXE="/epanet/build/bin/runepanet"
if [ ! -f "$SUT_EXE" ]; then
    echo "ERROR: EPANET executable not found at $SUT_EXE."
    exit 1
fi

# --------------------------------
# 2) Download epanet-example-networks
# --------------------------------
echo "INFO: Downloading official EPANET example networks..."

# A) Determine the latest release tag:
LATEST_URL="${EXAMPLES_REPO}/releases/latest"
LATEST_TAG=$(curl -sI "$LATEST_URL" | grep -Po 'tag\/\K(v\S+)' || true)
if [ -z "$LATEST_TAG" ]; then
  echo "WARNING: Could not retrieve the latest tag. Fallback to 'master'"
  LATEST_TAG="master"
fi

mkdir -p "$TEST_HOME"
cd "$TEST_HOME"
rm -rf ./*

ARCHIVE_URL="https://codeload.github.com/OpenWaterAnalytics/epanet-example-networks/tar.gz/${LATEST_TAG}"
echo "INFO: Downloading $ARCHIVE_URL ..."
curl -fsSL -o examples.tar.gz "$ARCHIVE_URL"
tar xzf examples.tar.gz && rm examples.tar.gz

# Suppose the extracted folder is named epanet-example-networks-<tag minus the 'v'>
BASENAME="epanet-example-networks-${LATEST_TAG#v}"
if [ ! -d "$BASENAME" ]; then
  echo "ERROR: Could not find extracted folder $BASENAME"
  ls -l
  exit 1
fi
# Link epanet-tests to a "tests" folder
ln -s "${BASENAME}/epanet-tests" tests

cd /epanet

# ------------------------------------------------
# 3) Generate the nrtest "app config" JSON for SUT
# ------------------------------------------------
mkdir -p "$TEST_HOME/apps"
APP_CONFIG="$TEST_HOME/apps/${PROJECT}-${SUT_BUILD_ID}.json"

cat <<EOF > "$APP_CONFIG"
{
   "name" : "epanet",
   "version" : "unknown",
   "description" : "${PLATFORM} ${SUT_BUILD_ID}",
   "setup_script" : "",
   "exe" : "${SUT_EXE}"
}
EOF

echo "INFO: Created nrtest app config at $APP_CONFIG."

# ---------------------------------------------------------
# 4) [Optional] Download and extract official reference for v2.2
# ---------------------------------------------------------
if [ "$REF_BUILD_ID" == "2.2" ]; then
    echo "INFO: Downloading official reference benchmark for EPANET 2.2..."
    REF_URL="https://github.com/OpenWaterAnalytics/epanet-example-networks/releases/download/v1.0.2-dev.10/benchmark-linux-220dev1.tar.gz"

    cd "$TEST_HOME"
    mkdir -p benchmark
    curl -fsSL -o ref_bench.tar.gz "$REF_URL"
    tar xzf ref_bench.tar.gz -C benchmark
    rm ref_bench.tar.gz

    # After extraction, you might see something like:
    #   benchmark/epanet-2.2/<test-output>.json
    # Adjust if the extracted folder name differs
    # E.g., if it extracted "epanet-220dev1", rename it:
    if [ -d "benchmark/epanet-220dev1" ]; then
        mv benchmark/epanet-220dev1 benchmark/epanet-2.2
    fi
fi

# ----------------------------------------
# 5) Run nrtest on official test suite
# ----------------------------------------
cd "$TEST_HOME"
OUTPUT_PATH="./benchmark/${PROJECT}-${SUT_BUILD_ID}"
rm -rf "$OUTPUT_PATH"

TEST_FILES=$(ls -1 ./tests/*/*.json)
if [ -z "$TEST_FILES" ]; then
    echo "ERROR: No test JSON files found!"
    exit 1
fi

echo "INFO: Running nrtest execute on all detected tests..."
nrtest execute "$APP_CONFIG" $TEST_FILES -o "$OUTPUT_PATH" || echo "WARNING: nrtest execute errors found."

# -----------------------------
# 6) Compare to Reference if present
# -----------------------------
if [ "$REF_BUILD_ID" == "2.2" ]; then
    REF_PATH="./benchmark/epanet-2.2"
    if [ -d "$REF_PATH" ]; then
      echo "INFO: Comparing SUT artifacts to reference $REF_BUILD_ID..."
      nrtest compare "$OUTPUT_PATH" "$REF_PATH" --rtol 0.01 --atol 1e-6
    else
      echo "WARNING: No reference benchmark found at $REF_PATH"
    fi
fi

# ---------------------------------------
# 7) Run private tests if mounted at /custom_tests
# ---------------------------------------
if [ -d "/custom_tests" ]; then
    echo "INFO: Found /custom_tests. Executing nrtest on it..."
    nrtest execute "$APP_CONFIG" /custom_tests -o ./benchmark/custom_${SUT_BUILD_ID} || true
fi

echo "INFO: EPANET regression test completed."
