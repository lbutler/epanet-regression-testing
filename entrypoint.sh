#!/bin/bash
set -e  # Exit on error

echo "INFO: Starting EPANET regression test inside Docker."
echo "INFO: REF_TAG=${REF_TAG}, SUT_TAG=${SUT_TAG}"

#----------------------------------
# 1) Clone EPANET Once (Full Clone)
#    so we can checkout branches or commits.
#----------------------------------
REPO_URL="https://github.com/OpenWaterAnalytics/EPANET.git"
SRC_DIR="/epanet/src"

if [ ! -d "$SRC_DIR/.git" ]; then
  echo "INFO: Cloning full EPANET repository..."
  git clone "$REPO_URL" "$SRC_DIR"
else
  echo "INFO: Repository already exists. Fetching latest changes..."
  cd "$SRC_DIR"
  git fetch --all
fi

#----------------------------------
# 2) Create Working Copies for REF and SUT
#----------------------------------
echo "INFO: Creating separate copies for reference and SUT builds..."
rm -rf /epanet/ref /epanet/sut
cp -r "$SRC_DIR" /epanet/ref
cp -r "$SRC_DIR" /epanet/sut

#----------------------------------
# 3) Checkout the Correct Version for REF & SUT
#    (branch, tag, or commit)
#----------------------------------
checkout_version() {
  local work_dir="$1"
  local version="$2"
  cd "$work_dir"

  # If "version" is a commit hash (7+ hex chars), just checkout directly;
  # otherwise assume it's a branch or tag and fetch + checkout.
  if [[ "$version" =~ ^[a-fA-F0-9]{7,}$ ]]; then
    echo "INFO: Checking out commit $version in $work_dir..."
    # If commit not in local clone, fetch it
    git fetch origin "$version"
    git checkout "$version"
  else
    echo "INFO: Checking out branch/tag $version in $work_dir..."
    git fetch origin "$version"
    git checkout "$version"
  fi
}

checkout_version "/epanet/ref" "$REF_TAG"
checkout_version "/epanet/sut" "$SUT_TAG"

#----------------------------------
# 4) Build Each Version
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
  # Return to source root
  cd "$src_dir"
}

build_epanet "/epanet/ref" "Reference Build"
build_epanet "/epanet/sut" "SUT Build"

#----------------------------------
# 5) Download Standard Test Suite (if DO_STANDARD_TEST=true)
#----------------------------------
if [ "$DO_STANDARD_TEST" = "true" ]; then
  echo "INFO: Downloading official EPANET example networks for standard tests..."
  mkdir -p "$TEST_HOME"
  cd "$TEST_HOME"
  rm -rf ./*

  # EXAMPLES_REPO should be set to: https://github.com/OpenWaterAnalytics/epanet-example-networks
  # Or some other environment variable if you prefer
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

  EXTRACTED_DIR="epanet-example-networks-${LATEST_TAG#v}/epanet-tests"

  if [ ! -d "$EXTRACTED_DIR" ]; then
    echo "ERROR: Could not find extracted folder $EXTRACTED_DIR"
    ls -l
    exit 1
  fi

  # Remove symlink and use the real directory
  rm -rf "$TEST_HOME/tests"
  mv "$EXTRACTED_DIR" "$TEST_HOME/tests"
fi

#----------------------------------
# 6) nrtest "app config" JSON for each version
#----------------------------------
mkdir -p "$TEST_HOME/apps"

cat <<EOF > "$TEST_HOME/apps/epanet-ref.json"
{
  "name" : "epanet-ref",
  "version" : "unknown",
  "description" : "${PLATFORM} reference",
  "setup_script" : "",
  "exe" : "/epanet/ref/build/bin/runepanet"
}
EOF

cat <<EOF > "$TEST_HOME/apps/epanet-sut.json"
{
  "name" : "epanet-sut",
  "version" : "unknown",
  "description" : "${PLATFORM} SUT",
  "setup_script" : "",
  "exe" : "/epanet/sut/build/bin/runepanet"
}
EOF

#----------------------------------
# 7) Run nrtest on Standard Tests (if DO_STANDARD_TEST=true)
#----------------------------------
if [ "$DO_STANDARD_TEST" = "true" ]; then
  echo "INFO: Running nrtest on standard tests..."
  cd "$TEST_HOME"

  TEST_FILES=$(find "$TEST_HOME/tests" -type f -name '*.json' 2>/dev/null)

  if [ -z "$TEST_FILES" ]; then
    echo "WARNING: No test JSON files found! Standard tests skipped."
  else
    nrtest execute "$TEST_HOME/apps/epanet-ref.json" $TEST_FILES -o "$TEST_HOME/benchmark/epanet-ref"
    nrtest execute "$TEST_HOME/apps/epanet-sut.json" $TEST_FILES -o "$TEST_HOME/benchmark/epanet-sut"

    echo "INFO: Comparing epanet-sut to epanet-ref..."
    nrtest compare "$TEST_HOME/benchmark/epanet-sut" "$TEST_HOME/benchmark/epanet-ref" --rtol 0.01 --atol 1e-6
  fi
else
  echo "INFO: Skipping standard tests per DO_STANDARD_TEST=false."
fi

#----------------------------------
# 8) Run Custom Tests (if DO_CUSTOM_TEST=true)
#----------------------------------
if [ "$DO_CUSTOM_TEST" = "true" ]; then
  if [ -d "/custom_tests" ]; then
    echo "INFO: Running nrtest on custom test cases..."
    mkdir -p "$TEST_HOME/benchmark"
    nrtest execute "$TEST_HOME/apps/epanet-sut.json" /custom_tests -o "$TEST_HOME/benchmark/custom_sut" || true
  else
    echo "INFO: DO_CUSTOM_TEST=true but no /custom_tests directory found."
  fi
fi

echo "INFO: EPANET regression test completed successfully."
