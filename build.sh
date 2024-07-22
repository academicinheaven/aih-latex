#!/bin/bash
# Shell script for building Docker image

IMAGE_NAME="aih-tex"
IMAGE_TAG="latest"
USERNAME=$USER
SOURCEFILE="versions.txt"
PARAMETERS=""
ENVIRONMENT_FILE="env.yaml.lock"

usage ()
{
    printf 'Builds the Docker image from the Dockerfile\n'
    printf 'Usage: %s [ dev | update | freeze | push ]\n\n' "$0"
    printf 'Commands(s):\n'
    printf "  dev: Build development image (create $USERNAME/$IMAGE_NAME:dev)\n"
    printf '  freeze: Update env.yaml.lock and ignore Docker cache\n'
    printf '  push: Push Docker image to repository\n'
    printf '  test: Run tests\n'
    printf '  update: Force fresh build, ignoring cached build stages and versions from lock (will e.g. update Python packages)\n'   
}

build ()
{
  if [[ -s $SOURCEFILE ]]; then
    echo Loading version information from "$SOURCEFILE".
    source $SOURCEFILE
  fi
  echo
  echo Building "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
  echo
  echo Settings:
  echo "--------"
  echo Micromamba: "$MICROMAMBA_VERSION"
  echo Parameters: "$PARAMETERS"
  echo Environment file: "$ENVIRONMENT_FILE"
  # Copy files to build context
  cp -r ../git_submodules/dockerfiles/common .
  docker build $PARAMETERS \
  --build-arg="MICROMAMBA_VERSION=$MICROMAMBA_VERSION" \
  --progress=plain --tag "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" .
  echo Build complete.
  return 0
  }

update ()
{
   # TBD: The tag could also be provided by versions-dev.txt
   IMAGE_TAG="dev"
   # removed for debugging PARAMETERS="--no-cache"
   SOURCEFILE="versions-dev.txt"
   ENVIRONMENT_FILE="env.yaml"
   echo UPDATE
   echo "- ignoring pinned versions from env.yaml.lock"
   echo "- using versions and settings from versions-dev.txt"
   echo "- ignoring cached build stages (will e.g. update Python packages)"
   echo
   echo "Note: env.yaml.lock will not be overwritten (use ./build.sh freeze for this)" 
   # Update git submodules
   git submodule update --init --recursive
   cd ../git_submodules/dockerfiles
   git fetch
   git checkout main  # Replace 'main' with the branch you are tracking
   git pull           # Pull the latest changes
   cd ../../aih-texlive
   # staging / commit / push will be up to the developer   
   # Update Seccomp profile
   echo Fetching the latest seccomp profile from https://github.com/moby/moby/blob/master/profiles/seccomp/default.json
   curl https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json -o seccomp-default.json
   build
   return 0
}

build_development_image () {
   IMAGE_TAG="dev"
   SOURCEFILE="versions-dev.txt"
   ENVIRONMENT_FILE="env.yaml.lock"
   echo BUILDING DEVELOPMENT IMAGE
   echo "- using pinned versions from env.yaml.lock"
   echo "- using versions and settings from versions-dev.txt"
   echo "- keeping cached build stages (use ./build.sh update to update Python packages)"
   echo
   echo "Note: env.yaml.lock will not be overwritten (use ./build.sh freeze for this)"
   build
   return 0
}

freeze () {
   IMAGE_TAG="dev"
   ENVIRONMENT_FILE="dev.yaml.lock"
   echo Writing $ENVIRONMENT_FILE from development image "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
   echo 
   echo "Note: Use ./build.sh to update the production image from this new lock file (copy / compare first)"
   docker run \
      --security-opt seccomp=seccomp-default.json \
      --security-opt=no-new-privileges \
      --read-only --tmpfs /tmp \
      --cap-drop all \
      --rm \
      "$USERNAME/$IMAGE_NAME:$IMAGE_TAG" \
      micromamba env export -n base > dev.yaml.lock
   echo Updated packages:
   echo "=== env.yaml.lock === | === dev.yaml.lock ==="
   diff -y --suppress-common-lines env.yaml.lock dev.yaml.lock > yaml.lock.diff.txt
   # Check the exit status of the diff command
   if [[ $? -eq 0 ]]; then
      echo "No changes"
   else
      cat yaml.lock.diff.txt
   fi
   rm -f yaml.lock.diff.txt
   return 0
}

push_to_hub () {
  echo Pushing images to Docker Hub
  docker login || return 1
  docker tag "$USERNAME/$IMAGE_NAME:latest" "mfhepp/$IMAGE_NAME:latest" || return 1
  docker push "mfhepp/$IMAGE_NAME:latest" || return 1
  docker tag "$USERNAME/$IMAGE_NAME:dev" "mfhepp/$IMAGE_NAME:dev" || return 1
  docker push "mfhepp/$IMAGE_NAME:dev" || return 1
  echo Success.
}

run_tests () {
   IMAGE_TAG="dev"
   NETWORK="--net=host"
   # Network is needed for Tectonic, can be turned off for TeX Live
   # NETWORK="--net=none"
   # TODO: Check if read-only filesystem can be made working
   READ_ONLY=""
   # READ_ONLY="--read-only --tmpfs /tmp"   
   echo Running tests against the development image "$USERNAME/$IMAGE_NAME:$IMAGE_TAG"
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
      echo "FAILED: One or more tests failed."
    else
      echo "PASSED: All tests passed."
    fi
    return $EXIT_CODE
}

if [[ "$1" == "--help" ]]; then
   usage
   exit 0
elif [[ $# -eq 0 || -z "$1" ]]; then
   build
   exit $?
elif [[ "$1" == "dev" ]]; then
   build_development_image
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
   exit $?
else
  echo "Invalid option."
  echo
  usage
  exit 1
fi