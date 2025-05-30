#!/usr/bin/env bash

################################################################################
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
################################################################################

echo "Create /sufp directory on LOAD_DRIVER ${LOAD_DRIVER}"
ssh root@${LOAD_DRIVER} "mkdir -p /sufp"
echo "Give permissions to sufp directory on LOAD_DRIVER ${LOAD_DRIVER}"
ssh root@${LOAD_DRIVER} "chmod -R 777"
echo "Transfering sufp scripts (pingperfPingScript.sh, cleanupScripts.sh, pingFirstResponse.sh) to load driver - ${LOAD_DRIVER}"
scp -r ${TEST_RESROOT}/scripts/sufp/scripts/pingperfPingScript.sh ${TEST_RESROOT}/scripts/sufp/scripts/cleanupScripts.sh ${TEST_RESROOT}/scripts/sufp/scripts/pingFirstResponse.sh root@${LOAD_DRIVER}:/sufp/ 



# Get the WL or OL build directory
BUILD_DIR=`ls ${LIBERTY_BINARIES_DIR} | grep "${LIBERTY_VERSION}-liberty"`
echo "BUILD_DIR=${BUILD_DIR}"
dirDate=`date "+%y%m%d_%k%M%S" | tr -d " "`
resDir=${LIBERTY_BINARIES_DIR}/libertyResults/${BUILD_DIR}/${APP}_${dirDate}
echo "Create resDir: ${resDir}"
mkdir -p ${resDir}
echo "LIBERTY_BINARIES_DIR=${LIBERTY_BINARIES_DIR}"
cd ${LIBERTY_BINARIES_DIR}/${BUILD_DIR}/wlp
${TEST_RESROOT}/scripts/sufp/scripts/sufpSetupServers.sh ${TEST_RESROOT}/scripts/sufp

cd ${LIBERTY_BINARIES_DIR}/${BUILD_DIR}/wlp
echo "Starting test on app: ${APP} for build: ${LIBERTY_BUILD_LEVEL}"
${TEST_RESROOT}/scripts/sufp/scripts/libertySufpCycles.sh ${resDir} ${LIBERTY_BUILD_LEVEL}_${APP}_${java}_two-warmups-cpus-4-runs-${MEASUREMENT_RUNS}-try-1 ${APP} ${MEASUREMENT_RUNS}
echo "Finished test on app: ${APP} for build: ${LIBERTY_BUILD_LEVEL}"


