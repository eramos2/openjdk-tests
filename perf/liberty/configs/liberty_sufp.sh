#!/usr/bin/env bash

#
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
#

echo "***** Running Benchmark Script *****"

echo "Current Dir: $(pwd)"

TEST_RESROOT=${1}

#### NEED TO CHECK WHAT IS AFFINITY SCRIPTS FOR AND HOW THEY ARE CONFIGURED IN JENKINS ####
# . "$TEST_RESROOT/../../../openjdk-tests/perf/affinity.sh" > /dev/null 2>&1
# setServerDBLoadAffinities --server-physcpu-num $SERVER_PHYSCPU_NUM --smt $SMT > /dev/null 2>&1

# export AFFINITY=${SERVER_AFFINITY_CMD}
# echo "AFFINITY=${AFFINITY}"

# if [ -z "${AFFINITY}" ]; then
#     echo "Warning!!! Affinity is NOT set. Affinity tool may NOT be installed/supported."
# fi

#TODO: Remove these once the use of STAF has been eliminated from all the benchmark scripts
export PATH=/usr/local/staf/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/staf/lib:$LD_LIBRARY_PATH

echo "JDK_VERSION=${JDK_VERSION}"

export JDK="j2sdk-image"
echo "JDK=${JDK}"

export JDK_DIR="${TEST_JDK_HOME}/.."
echo "JDK_DIR=${JDK_DIR}"

export JAVA_HOME="${JDK_DIR}/${JDK}/jre"
echo "JAVA_HOME=${JAVA_HOME}"

export APP="${1}"
echo "APP=${APP}"
shift

export TEST_RESROOT="${1}"
echo "TEST_RESROOT=${TEST_RESROOT}"
shift

export LIBERTY_VERSION="${1}"
echo "LIBERTY_VERSION=${LIBERTY_VERSION}"
shift

#TODO: Need to tune these options. Keeping them simple for now 
export JDK_OPTIONS="-Xmx256m"
export COLD="0"
export WARMUP="0"
export RESULTS_MACHINE="$(hostname)"
export ROOT_RESULTS_DIR="$(pwd)"
export RESULTS_DIR="libertyResults-cleaned"
export NO_SETUP="false"
export SETUP_ONLY="false"
export WARM="1"
export INSTALL_DIR=""
export LIB_PATH=""
export HEALTH_CENTRE=""
export COGNOS_WAIT=""
export REQUEST_CORE=""
export SCENARIO="sufp-${APP}"
export SERVER_NAME="${APP}"
export PETERFP="false"
export RESULTS_MACHINE="$(hostname)"
export RESULTS_DIR="libertyResults"
export LIBERTY_HOST="$(hostname)"
export LAUNCH_SCRIPT="server"
export LIBERTY_BINARIES_DIR="${TEST_RESROOT}/libertyBinaries"
export APP_VERSION="${APP}"
export WLP_SKIP_MAXPERMSIZE="1"
export ANT_HOME="/usr/share/ant"

bash ${TEST_RESROOT}/scripts/bin/sufp_benchmark.sh
