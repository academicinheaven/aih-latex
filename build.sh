#!/bin/bash
# Shell script for building Docker image

IMAGE_NAME="aih-latex"
IMAGE_TAG="latest"
USERNAME=$USER
DOCKER_HUB_USERNAME="mfhepp"
SOURCEFILE="versions.txt"
PARAMETERS=""
# We only build for Apple M1 for the moment
PLATFORM="linux/arm64"
ENVIRONMENT_FILE="env.yaml.lock"

usage ()
{
    printf '\nBuilds the Docker image from the Dockerfile\n\n'
    printf 'Usage: %s [ --help ] [ test | push | freeze | update ]\n\n' "$0"
    printf 'Commands(s):\n'
    printf '  (none): Build image\n'   
    printf '  test:   Run tests\n'
    printf '  push:   Push Docker image to repository\n'
    printf '  freeze: Create version folder and freeze version.txt and env.yaml.lock\n'
    printf '  update: Update submodules and external files\n'   
}


build ()
{
   if [ -s "$ENVIRONMENT_FILE" ]; then
      echo "Using pinned versions from $ENVIRONMENT_FILE"
   else
      ENVIRONMENT_FILE="env.yaml"
      if [ -s "$ENVIRONMENT_FILE" ]; then
         echo "Using dependencies from $ENVIRONMENT_FILE"
      else
         echo "ERROR: $ENVIRONMENT_FILE missing."
         return 1
      fi
   fi
   echo
   echo Building "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
   echo "Platform:              $PLATFORM"
   echo
   echo Settings:
   echo "------------------------------------------"
   echo "Micromamba:            $MICROMAMBA_VERSION"
   echo "Parameters:            $PARAMETERS"
   echo "Environment file:      $ENVIRONMENT_FILE"
   echo "PLATFORM: $PLATFORM"
   echo
   # Build image
   docker build --platform ${PLATFORM} ${PARAMETERS} \
   --build-arg PLATFORM=${PLATFORM} \
   --build-arg BUILDPLATFORM=${PLATFORM} \
   --build-arg MICROMAMBA_VERSION=${MICROMAMBA_VERSION} \
   --progress=plain --tag ${USERNAME}/${IMAGE_NAME}:${IMAGE_TAG} .
   if [[ $? -ne 0 ]]; then
      echo "ERROR: Docker build failed."
      return 1
   else
      echo "OK: Docker build succeeded."
   fi
   # Running tests
   run_tests
   return $?
   }


run_tests () {
   # IMAGE_TAG="dev"
   NETWORK="--net=none"
   # Use this if tests require network connection:
   # NETWORK="--net=host"
   # TODO: Check if read-only filesystem can be made working
   # READ_ONLY=""
   READ_ONLY="--read-only --tmpfs /tmp"   
   echo Running tests against the local image "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
   docker run \
    --security-opt seccomp=seccomp-default.json \
    --security-opt=no-new-privileges \
    --cap-drop all \
    $READ_ONLY \
    --rm \
    --mount type=bind,source="$(pwd)/output",target=/mnt/output \
    --mount type=bind,source="$(pwd)/tests",target=/usr/aih/data/src,readonly \
    $NETWORK \
    "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" \
    /bin/bash ./run_tests.sh "$@"
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
      echo "FAILED: One or more tests failed or image is not available."
    else
      echo "PASSED: All tests passed."
    fi
    return $EXIT_CODE
}


update ()
{
   echo Updating submodules and other components
   # Update git submodules
   git submodule update --init --recursive || return 1
   cd dockerfiles || return 1
   git fetch || return 1
   git checkout main  || return 1 # Replace 'main' with the branch you are tracking
   git pull          || return 1 # Pull the latest changes
   cd ..
   # Update Seccomp profile
   echo Updating the seccomp profile from https://github.com/moby/moby/blob/master/profiles/seccomp/default.json
   curl https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json -o seccomp-default.json || return 1
   # PARAMETERS="--no-cache"
   # ENVIRONMENT_FILE="env.yaml"
   echo "Note: env.yaml.lock will not be overwritten (use ./build.sh freeze for this)" 
   echo DO NOT FORGET to commit these changes!
   # build
   return 0
}


freeze () {
   mkdir -p freeze/${IMAGE_TAG}
   echo Copying ${SOURCEFILE} to freeze/${IMAGE_TAG}/${SOURCEFILE}
   cp ${SOURCEFILE} freeze/${IMAGE_TAG}/${SOURCEFILE} || return 1
   # Check if ENVIRONMENT_FILE ends with .lock or .yaml
   if [[ "$ENVIRONMENT_FILE" == *.lock ]]; then
      echo "Updating $ENVIRONMENT_FILE."
      cp ${ENVIRONMENT_FILE} ${ENVIRONMENT_FILE}.old || return 1
   elif [[ "$ENVIRONMENT_FILE" == *.yaml ]]; then
      echo "Creating $ENVIRONMENT_FILE.lock for $ENVIRONMENT_FILE"
      ENVIRONMENT_FILE="${ENVIRONMENT_FILE}.lock" 
   else
      echo "ERROR: $ENVIRONMENT_FILE does not end with .lock or .yaml"
      return 1
   fi
   docker run \
      --security-opt seccomp=seccomp-default.json \
      --security-opt=no-new-privileges \
      --read-only --tmpfs /tmp \
      --cap-drop all \
      --rm \
      "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" \
      micromamba env export -n base > ${ENVIRONMENT_FILE}
   if [[ $? -ne 0 ]]; then
      return $?
   fi
   echo Copying ${ENVIRONMENT_FILE} to freeze/${IMAGE_TAG}/${ENVIRONMENT_FILE} 
   cp ${ENVIRONMENT_FILE} freeze/${IMAGE_TAG}/${ENVIRONMENT_FILE}
   if [ -s "${ENVIRONMENT_FILE}.old" ]; then
      echo Updated packages:
      echo "=== NEW env.yaml.lock === | === PREVIOUS env.yaml.lock ==="
      diff -y --suppress-common-lines "${ENVIRONMENT_FILE}" "${ENVIRONMENT_FILE}.old" > yaml.lock.diff.txt
      # Check the exit status of the diff command
      if [[ $? -eq 0 ]]; then
         echo "No changes"
      else
         cat yaml.lock.diff.txt
      fi
      rm -f yaml.lock.diff.txt
   fi
   return 0
}


push_to_hub () {
  echo Pushing image "$IMAGE_NAME:$IMAGE_TAG" to "$DOCKER_HUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG" on Docker Hub
  docker login || return 1
  docker tag "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" "$DOCKER_HUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG" || return 1
  docker push "$DOCKER_HUB_USERNAME/$IMAGE_NAME:$IMAGE_TAG"  || return 1
  echo OK
}


# Load settings from version.txt
if [[ -s "$SOURCEFILE" ]]; then
   echo Loading version information from "$SOURCEFILE".
   source $SOURCEFILE
else
   echo "ERROR: $SOURCEFILE missing."
   return 1
fi 
if [[ "$1" == "--help" ]]; then
   usage
   exit 0
elif [[ $# -eq 0 || -z "$1" ]]; then
   build
   exit $?
elif [[ "$1" == "freeze" ]]; then
   freeze
   exit $?
elif [[ "$1" == "test" ]]; then
   run_tests
   exit $?
elif [[ "$1" == "update" ]]; then
   update
   exit $?
elif [[ "$1" == "push" ]]; then
   push_to_hub
   EXIT_CODE=$?
   if [[ $EXIT_CODE -ne 0 ]]; then
     echo "FAILED: One or more docker commands failed."
   fi
   exit $EXIT_CODE   
else
  echo "Invalid option."
  echo
  usage
  exit 1
fi