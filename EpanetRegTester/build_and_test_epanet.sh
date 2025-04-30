#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# You can change this base name if you prefer
readonly IMAGE_BASE_NAME="epanet-regtester"

# --- Argument Check ---
# Check if the first argument (the version) is provided
if [ -z "$1" ]; then
  echo "Error: No EPANET version specified."
  echo ""
  echo "Usage: $0 <epanet_version>"
  echo "  <epanet_version>: A Git commit hash, tag, or branch name (e.g., v2.2, master, a1b2c3d)"
  exit 1
fi

# --- Variables ---
# Assign the first argument to a variable
readonly EPANET_REF="$1"
# Construct the full image tag
readonly IMAGE_TAG="${IMAGE_BASE_NAME}:${EPANET_REF}"

# --- Build Phase ---
echo "--------------------------------------------------"
echo " Building Docker image for EPANET version: ${EPANET_REF}"
echo " Image tag will be: ${IMAGE_TAG}"
echo "--------------------------------------------------"

# Build the image using the provided version for the build argument and tag
docker build \
  --build-arg EPANET_VERSION="$EPANET_REF" \
  -t "$IMAGE_TAG" \
  . # Assumes Dockerfile is in the current directory

echo ""
echo "--------------------------------------------------"
echo " Build complete for ${IMAGE_TAG}"
echo "--------------------------------------------------"
echo ""

# --- Run Phase ---
echo "--------------------------------------------------"
echo " Running regression tests using image: ${IMAGE_TAG}"
echo "--------------------------------------------------"

# Run the container using the tag created above
# The container will be automatically removed on exit (--rm)
docker run --rm "$IMAGE_TAG"

echo ""
echo "--------------------------------------------------"
echo " Test run finished for version: ${EPANET_REF}"
echo "--------------------------------------------------"

exit 0