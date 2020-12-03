#!/usr/bin/env bash

set -eo pipefail

usage="Usage (all required): ./build.sh --username=<user> --password=<passwd> --repository=<repository>"
usage="${usage} --version=<liberty-version> --buildLabel=<build-label> --buildUrl=<build-url>"
readonly IMAGE_ROOT="ga/latest" # the name of the dir holding all versions
readonly REGISTRY="wasliberty-liber8-docker.artifactory.swg-devops.com"

## see EOF for call to main
main() {
  ## reads flags and sets global variables accordingly (see usage)
  parse_args $@

  case "$(uname -p)" in
  "ppc64le")
    readonly arch="ppc64le"
    ;;
  "s390x")
    readonly arch="s390x"
    ;;
  *)
    readonly arch="amd64"
    ;;
  esac

  ## if master branch set push to true and login to registry
  push="false"
  if [ "$TRAVIS" == "true" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_BRANCH" == "master" ]
  then
    push="true"

    ## retry command in case registry is slow or busy
    for i in {1..5}; do
        echo "${PASS}" | docker login "${REGISTRY}" -u "${USER}" --password-stdin && break || s=$? && sleep 15
    done
    if [ ! $s -eq 0 ]; then
        echo "Failed to log in to ${REGISTRY} as ${USER}"
        exit 1
    fi
  else
    echo "Not pushing images to artifactory because this is not a Travis build of the master branch."
  fi

  ## custom build parameters for the dockerfiles
  readonly WGET_ARGS="--progress=bar:force --no-check-certificate --user=${USER} --password=${PASS}"

  ## build necessary base image for one of the ubi images
  build_ibm_java

  ## build tags, expand this as requirements change
  local tags=(kernel)

  for tag in "${tags[@]}"; do
    build_latest_tag $tag
  done
}
## reads flags and sets global variables accordingly
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
        --username=*)
        readonly USER="${1#*=}"
        ;;
        --password=*)
        readonly PASS="${1#*=}"
        ;;
        --repository=*)
        readonly REPO="${1#*=}"
        ;;
        --version=*)
        ## currently unused variable but ideally dockerfiles take as arg
        readonly LIBERTY_VERSION="${1#*=}"
        ;;
        --buildLabel=*)
        readonly LIBERTY_LABEL="${1#*=}"
        ;;
        --buildUrl=*)
        readonly LIBERTY_URL="${1#*=}"
        ;;
        --baseTag=*)
        baseTag="${1#*=}"
        ;;
        --fileName=*)
        fileName="${1#*=}"
        ;;
        *)
        echo "Error: Invalid argument - $1"
        echo "$usage"
        exit 1
    esac
    shift
  done

  if [[ -z "${USER}" || -z "${PASS}" || -z "${REPO}" ]]; then
    echo "****** Error: missing docker repository constants"
    echo "${usage}"
    exit 1
  fi

  if [[ -z "${LIBERTY_LABEL}" || -z "${LIBERTY_URL}" ]]; then
    echo "****** Error: missing critical build information from arguments"
    echo "${usage}"
    exit 1
  fi
}

## @param $image this is the full tag reference including repo
## @param $docker_dir this the directory containing the docker file
## @param $file_name the actual file name as we don't use Dockerfile for WASDev
build_liberty_with_tag() {
  local image="$1"; shift
  local docker_dir="$1"; shift
  local file_name="$1"
  ## build using the custom download url and wget flags
  docker build --no-cache=true -t "${image}" \
    --build-arg LIBERTY_URL="${LIBERTY_URL}" \
    --build-arg DOWNLOAD_OPTIONS="${WGET_ARGS}" \
    -f "${docker_dir}/${file_name}" \
    "${docker_dir}"
}

## builds 'ibmjava:8-ubi' for the ibmjava ubi image
build_ibm_java() {
  docker pull registry.access.redhat.com/ubi8/ubi
  ## pull Dockerfile from ibmjava
  echo "Current working dir: in build-wasperf.sh"
  pwd
  ls java
  cat java/Dockerfile
  ## Create directory if it doesn't already exist
  mkdir -p java
  wget https://raw.githubusercontent.com/ibmruntimes/ci.docker/master/ibmjava/8/jre/ubi/Dockerfile -O java/Dockerfile
  echo "Do we get here in build-wasperf.sh?"
  ## replace references to user 1001 as we need to build as root
  sed -i.bak '/useradd -u 1001*/d' ./java/Dockerfile && sed -i.bak '/USER 1001/d' ./java/Dockerfile && rm java/Dockerfile.bak
  docker build -t ibmjava:8-ubi java
}

## we only build full for daily, here building the kernel Dockerfiles but giving them full.zip
build_latest_tag() {
    local tag="$1"
    # set image information arrays
    local file_exts_ubi=($fileName)
    local tag_exts_ubi=($baseTag)

    for i in "${!tag_exts_ubi[@]}"; do
        local docker_dir="${IMAGE_ROOT}/${tag}"
        local full_path="${docker_dir}/Dockerfile.${file_exts_ubi[$i]}"
        if [[ -f "${full_path}" ]]; then
            local build_tag="${REPO}:full-${tag_exts_ubi[$i]}"

            echo "****** Building image ${build_tag}..."
            build_liberty_with_tag "${build_tag}" "${docker_dir}" "Dockerfile.${file_exts_ubi[$i]}"
            ## run all tests on this image
            confirm_tag "${build_tag}"
            ## push to REGISTRY
            push_tag "${build_tag}"
        else
            echo "Could not find Dockerfile at path ${full_path}"
            exit 1
        fi
    done
}

## @param tag the :${tag} of the image being built & tested currently
confirm_tag() {
    ## local variables are passed to methods they call, bad practice but
    ## we rely on it here so tests can be looped through without explicit call
    local image="$1"
    ## grabs every test method defined at bottom of file
    local tests=$(declare -F | cut -d" " -f3 | grep "^test")
    echo "**** Testing $image ****"
    for name in $tests; do
        echo "*** ${name} - Executing"
        eval $name
        echo "*** ${name} - Completed successfully"
    done
}
## @param from the tag that was built
## @param to is the tag that is being pushed, including the remote registry
push_tag() {
  local from="$1"
  local to="${REGISTRY}/${from}-${arch}"
  docker tag "${from}" "${to}"

  if [[ "${push}" = "true" ]]; then
      for i in {1..5}; do
          docker push "${to}" && s=0 && break || s=$? && sleep 15
      done
      if [ ! $s -eq 0 ]; then
          echo "Error: Failed to push ${to}"
          exit 1
      fi
  else
      echo "****** Not pushing to ${REGISTRY} as this is not the master branch"
  fi
}

## tests from all liberty docker repos
waitForServerStart()
{
   cid=$1
   count=${2:-1}
   end=$((SECONDS+120))
   while (( $SECONDS < $end && $(docker inspect -f {{.State.Running}} "${cid}") == "true" ))
   do
      result=$(docker logs "${cid}" 2>&1 | grep "CWWKF0011I" | wc -l)
      if [ $result = $count ]
      then
         return 0
      fi
   done

   echo "Liberty failed to start the expected number of times"
   return 1
}

waitForServerStop()
{
   cid=$1
   end=$((SECONDS+120))
   while (( $SECONDS < $end ))
   do
      result=$(docker logs "${cid}" 2>&1 | grep "CWWKE0036I" | wc -l)
      if [ $result = 1 ]
      then
         return 0
      fi
   done

   echo "Liberty failed to stop within a reasonable time"
   return 1
}

testDockerOnOpenShift()
{
   testLibertyStopsAndRestarts "OpenShift"
}

testLibertyStopsAndRestarts()
{
    echo "Running image: ${image}"
    if [ "$1" == "OpenShift" ]; then
        timestamp=$(date '+%Y/%m/%d %H:%M:%S')
        echo "$timestamp *** testLibertyStopsAndRestarts on OpenShift"
        cid=$(docker run -d -u 1005:0 $image)
    else
    cid=$(docker run -d $image)
    fi
    echo "Waiting for server to start..."
    waitForServerStart "${cid}" \
        || handle_test_failure "${cid}" "starting"
    ## give server time to start up
    sleep 30

    echo "Stopping server..."
    docker stop "${cid}" >/dev/null \
        || handle_test_failure "${cid}" "stopping"
    ## give server time to stop
    sleep 30

    echo "Starting the server again..."
    docker start "${cid}" >/dev/null \
        || handle_test_failure "${cid}" "starting"

    echo "Waiting for server to restart..."
    waitForServerStart "${cid}" 2 \
        || handle_test_failure "${cid}" "starting"

    echo "Checking container logs for errors..."
    ## if it finds NO errors the grep *fails* as it found nothing
    ## therefore we make the conditional true in the catch
    local pass
    docker logs "${cid}" 2>&1 | grep "ERROR" \
        || pass="passed"; true

    if [[ -z "${pass}" ]]; then
        echo "Errors found in logs for container; exiting"
        echo "DEBUG START full log"
        docker logs "${cid}"
        echo "DEBUG END full log"
        docker rm -f "${cid}" >/dev/null
        exit 1
    fi
    echo "Removing container: ${cid}"
    docker rm -f "${cid}" >/dev/null
}

handle_test_failure () {
    local cid="$1"; shift
    local process="$1"
    echo "Error ${process} container or server; exiting"
    docker logs "${cid}"
    docker rm -f "${cid}" >/dev/null
    exit 1
}

main $@
