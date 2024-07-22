#!/usr/bin/env bash
# Shell script for starting Docker container
# Naming inside the Docker container:
# TODO: This will change!
# /usr/aih/data/src
# /usr/aih/data/output
# /usr/aih/formats
# /usr/aih/formats/user
# /usr/aih/references
# /usr/aih/settings
# /usr/aih/filters
# /usr/aih/filters/user
# /usr/aih/styles

IMAGE_NAME="aih-tex"
USERNAME=$USER
COMMAND=""
PARAMETERS=""
NETWORK="--net=host"
# Network is needed for Tectonic, can be turned off for TeX Live
# NETWORK="--net=none"
# TODO: Check if read-only filesystem can be made working
READ_ONLY=""
# READ_ONLY="--read-only --tmpfs /tmp"

usage ()
{
    printf "Shell script for starting Docker container from image ${USERNAME}/${IMAGE_NAME}\n"
    printf "Usage: %s [ --latest | --dev | --<tag> ] (default is ${USERNAME}/${IMAGE_NAME}:latest)\n\n"
}

# Check if the argument is provided
if [ -z "$1" ]; then
  IMAGE_TAG="latest"
  COMMAND="/bin/bash"
  PARAMETERS="-it"
  echo "Starting ${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} in interactive mode."
elif [[ "$1" == "--help" ]]; then
   usage
   exit 0
elif [[ "$1" == --* ]]; then
  # Extract the part after "--"
  IMAGE_TAG="${1#--}"
  shift
  if [[ $# -eq 0 ]]; then
    echo "Starting ${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} in interactive mode."
    COMMAND="/bin/bash"
    PARAMETERS="-it"    
  else
    echo "Starting ${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} with the following commands:"
    echo "    $@"
  fi
else
    IMAGE_TAG="latest"
    echo "Starting ${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} the following commands:"
    echo "    $@"
fi

FULL_IMAGE_NAME="${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
# Check if the image exists locally

if docker images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${FULL_IMAGE_NAME}$"; then
  echo "OK: Image ${FULL_IMAGE_NAME} found."
  mkdir -p output
  docker run \
    $PARAMETERS \
    --security-opt seccomp=seccomp-default.json \
    --security-opt=no-new-privileges \
    --cap-drop all \
    $READ_ONLY \
    --rm \
    --mount type=bind,source="$(pwd)/output",target=/mnt/output \
    --mount type=bind,source="$(pwd)",target=/usr/aih/data/src,readonly \
    $NETWORK \
    "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" \
    $COMMAND "$@"
else
  echo "ERROR: ${IMAGE_TAG} does not exist for the image ${USERNAME}/${IMAGE_NAME}"
  exit 1
fi
