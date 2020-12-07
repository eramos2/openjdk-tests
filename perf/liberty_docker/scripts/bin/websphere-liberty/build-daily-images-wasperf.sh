#!/usr/bin/env bash

set -Eeo pipefail

readonly REPO="websphere-liberty-daily"
readonly VERSION="20.0.0.6"
readonly DOWNLOAD_URL="https://libfsfe04.hursley.ibm.com/liberty/dev/Xo/release"
#readonly DOWNLOAD_URL="https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/nightly/"
readonly USERNAME="$1"
readonly PASSWORD="$2"

readonly BUILD="${3}"
readonly BASE_TAG="${4}"
readonly CI_DOCKER="${5}"
echo "Settings inside build-daily-images-wasperf.sh"
echo $USERNAME
echo $PASSWORD
echo $BUILD
echo $BASE_TAG
#echo $BUILD

if [[ ${BASE_TAG} == *java8-openj9-ubi* ]]
then
  FILE_NAME="ubi.adoptopenjdk8"
elif [[ ${BASE_TAG} == *java11-openj9-ubi* ]]
then
  FILE_NAME="ubi.adoptopenjdk11"
elif [[ ${BASE_TAG} == *java8-ibmjava-ubi* ]]
then
  FILE_NAME="ubi.ibmjava8"
elif [[ ${BASE_TAG} == *java8-ibmjava* ]]
then
  FILE_NAME="ubuntu.ibmjava8"
else
  echo "ERROR"
  exit
fi

main() {
  if [[ -z "${USERNAME}" || -z "${PASSWORD}" ]]; then
    echo "****** Error: w3 authentication not set, exiting..."
    exit 1
  fi

  echo "****** Querying for last successful build..."
  local full_build_label=$(get_full_build_label)
  
  if [[ $full_build_label == "" ]]
  then
    echo "${BUILD} not found"
    exit
  fi

  echo "****** Full Build Label: ${full_build_label}"
  ## Removes everything up to the % symbol
  local short_build_label=$(format_short_build_label "${full_build_label}")
  local liberty_url=$(format_liberty_url "${full_build_label}")
  cd $CI_DOCKER
  #APP_DEST=/root/workspace/Test_openjdk8_j9_extended.perf_x86-64_linux_liberty-docker-sufp@2/openjdk-tests/TKG/../../jvmtest/perf/liberty_docker/CL-docker-images
  #Current directory=/root/workspace/Test_openjdk8_j9_extended.perf_x86-64_linux_liberty-docker-sufp@2/openjdk-tests/TKG/../../jvmtest/perf/liberty_docker/scripts/bin/websphere-liberty
  echo "Current directory=$(dirname $0)"
  echo "****** Running WL build script in $(pwd) with:"
  echo "Build label: ${short_build_label}"
  echo "Build URL: ${liberty_url}"
  $(dirname $0)/build-wasperf.sh --username="${USERNAME}" --password="${PASSWORD}" --repository="${REPO}" \
              --version="${VERSION}" --buildLabel="${short_build_label}" --buildUrl="${liberty_url} --baseTag="${BASE_TAG} --fileName="${FILE_NAME}"
  #docker tag websphere-liberty-daily:full-${BASE_TAG} websphere-liberty:full
  docker tag websphere-liberty-daily:full-${BASE_TAG} websphereliberty/daily:latest
  echo "Finished main in build-daily-images-wasperf.sh"
  pwd

}
## @returns the last good build's label as a string
get_full_build_label() {
  ## last.good.build.label is a text file containing the last good build label for convenience
  ## --anyauth checks what auth is required and uses it's safest protocol automatically
  if [[ ${BUILD} == "latest" ]] 
  then
    echo $(curl -k -u "${USERNAME}:${PASSWORD}" "${DOWNLOAD_URL}/last.good.build.label")
  else
    while IFS= read -r line
    do
      printf '%s\n' "$line"
    done < <(curl -L -k -u "${USERNAME}:${PASSWORD}" "${DOWNLOAD_URL}" | sed -n -r "s@.*(${BUILD}-.*?)/</a>.*@\1@p" )
 fi
  
}
## @returns the build label without the extra id string at the end, as used to label docker image
format_short_build_label() {
  local full_build_label="$1"
  echo "${full_build_label%-_*}"
}
## @returns the URL to full.zip file that will be used as an arg during docker build
format_liberty_url() {
  local full_build_label="$1"
  local build_label=$(format_short_build_label "${full_build_label}")
  echo "${DOWNLOAD_URL}/${full_build_label}/wlp-${build_label}.zip"
}

is_build_link() {
    local link_tag="$1"
    [[ $link_tag =~ .*([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{4}).* ]]
}


main $@
########## Not currently used ##########
# The below is necessary if in the future we decide to build kernel daily images
# alongside full, but as of now we just take the full zip for daily.
# kernel url: ${DOWNLOAD_URL}/${full_build_label}/fe/${build_name}/linux/zipper/externals/installables/

## @returns the selected build's name as a string
## downloads build directory structure and traverses it to get name of directory labelled after build name
get_build_name() {
  local build_path="$1"
  local url="https://${build_path}"
  ## get build dirs
  wget --no-parent --spider -r -l1 --no-check-certificate --user="${USERNAME}" --password="${PASSWORD}" "${url}" > /dev/null 2>&1
  ## traverse and print the directory named after build
  local name=$(ls ${build_path})
  rm -rf libfsfe01.hursley.ibm.com
  echo "${name}"
}
