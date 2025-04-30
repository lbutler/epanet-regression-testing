#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
readonly IMAGE_BASE_NAME="epanet-regtester" # Should match the testing script
readonly REFERENCE_VERSION="v2.2" # Define the specific version for reference files
readonly OWA_DIR="OWAFile"        # The directory containing .inp files (relative to script location)

# --- Argument Check ---
# Check if the OWAFile directory exists
if [ ! -d "$OWA_DIR" ]; then
  echo "Error: Directory '$OWA_DIR' not found in the current location."
  echo "Please ensure the script is run from the directory containing '$OWA_DIR'."
  exit 1
fi

# Construct the full image tag for the reference version
readonly IMAGE_TAG="${IMAGE_BASE_NAME}:${REFERENCE_VERSION}"

# --- Build Phase (for Reference Version) ---
echo "--------------------------------------------------"
echo " Building Docker image for EPANET reference version: ${REFERENCE_VERSION}"
echo " Image tag will be: ${IMAGE_TAG}"
echo " (Using Dockerfile in current directory)"
echo "--------------------------------------------------"

# Build the image using the reference version
# Ensure the Dockerfile is the updated one that includes runepanet
docker build \
  --build-arg EPANET_VERSION="$REFERENCE_VERSION" \
  -t "$IMAGE_TAG" \
  .

echo ""
echo "--------------------------------------------------"
echo " Build complete for ${IMAGE_TAG}"
echo "--------------------------------------------------"
echo ""

# --- Reference File Generation Phase ---
echo "--------------------------------------------------"
echo " Generating reference .out files in host directory: './${OWA_DIR}'"
echo " Using image: ${IMAGE_TAG}"
echo "--------------------------------------------------"

# Define the command to run inside the container
# It changes to the mounted directory, loops through .inp files,
# and runs runepanet for each, outputting .rpt and .out files
# with the same base name directly into the mounted directory.
readonly CONTAINER_COMMAND="cd /data && \
  echo '--- Starting reference file generation inside container ---' && \
  for inp_file in *.inp; do \
    if [ -f \"\$inp_file\" ]; then \
      base_name=\$(basename \"\$inp_file\" .inp); \
      echo \"Processing '\$inp_file' -> '\${base_name}.out'...\"; \
      /usr/local/bin/runepanet \"\$inp_file\" \"\${base_name}.rpt\" \"\${base_name}.out\"; \
    else \
      echo 'Warning: No .inp files found in /data'; \
      break; \
    fi; \
  done && \
  echo '--- Reference file generation complete inside container ---'"

# Run the container:
# --rm : Remove container after exit
# -v   : Mount the local OWA_DIR to /data inside the container
# --entrypoint /bin/bash : Override the default entrypoint
# IMAGE_TAG : The specific image built for the reference version
# -c "$CONTAINER_COMMAND" : Execute the loop command using bash
docker run \
  --rm \
  -v "$(pwd)/${OWA_DIR}":/data \
  --entrypoint /bin/bash \
  "$IMAGE_TAG" \
  -c "$CONTAINER_COMMAND"

echo ""
echo "--------------------------------------------------"
echo " Reference file generation process finished."
echo " Check './${OWA_DIR}' for updated .out files."
echo "--------------------------------------------------"

exit 0
