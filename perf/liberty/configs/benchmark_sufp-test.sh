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

#TODO: Remove these once the use of STAF has been eliminated from all the benchmark scripts
export PATH=/usr/local/staf/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/staf/lib:$LD_LIBRARY_PATH


echo "JDK_VERSION=${JDK_VERSION}"
echo "${MEASUREMENT_RUNS}"
export JDK="j2sdk-image"
echo "JDK=${JDK}"

export JDK_DIR="${TEST_JDK_HOME}/.."
echo "JDK_DIR=${JDK_DIR}"

export JAVA_HOME="${JDK_DIR}/${JDK}/jre"
echo "JAVA_HOME=${JAVA_HOME}"

export apps="${1}"
echo "apps=${apps}"

shift
######### Generated Script #########

# if [ -z "${DB_SETUP}" ]; then
# 	#TODO: Need to do some cleanup and restructure some files for adding other configs
# 	echo ""
# 	echo "********** START OF NEW TESTCI BENCHMARK JOB **********"
# 	echo "Benchmark Name: LibertyStartupFootprint Benchmark Variant: 17dev-4way-0-256-qs"
# 	echo "Benchmark Product: ${JDK}"
# 	echo ""
# fi

#TODO: Need to tune these options. Keeping them simple for now 
export JDK_OPTIONS="-Xmx256m"
export COLD="0"
export WARMUP="0"
export NO_SETUP="false"
export SETUP_ONLY="false"
export WARM="1"
export INSTALL_DIR=""
export LIB_PATH=""
export HEALTH_CENTRE=""
export COGNOS_WAIT=""
export REQUEST_CORE=""
export SCENARIO="sufp-${app}"
#export SERVER_NAME="LibertySUDTServer-$JDK"
export SERVER_NAME="${app}"
export PETERFP="false"
export RESULTS_MACHINE="panthers1.rtp.raleigh.ibm.com"
export RESULTS_DIR="libertyResults"
export LIBERTY_HOST="$(hostname)"
export LAUNCH_SCRIPT="server"
export LIBERTY_BINARIES_DIR="$1/libertyBinaries"
export LIBERTY_VERSION="openliberty-19.0.0.4"
export APP_VERSION="${app}"
export WLP_SKIP_MAXPERMSIZE="1"
export ANT_HOME="/usr/share/ant"
export MEASUREMENT_RUNS=${MEASUREMENT_RUNS}
export LIBERTY_BUILD_REPO=${LIBERTY_BUILD_REPO}
#Expects 'latest' or 'cl200720200614-1100'
export LIBERTY_BUILD_LEVEL=${LIBERTY_BUILD_LEVEL}
export LIBERTY_VERSION=${LIBERTY_VERSION}
export LIBERTY_RELEASE=${LIBERTY_RELEASE}
##TODO: need to add pasword variable get it from generalLookupFile = '%s/../cfg/utils/general_lookup.txt' % wpa_path

#TODO: Need to soft-code these configs. Need to add various affinity tools in the perf pre-reqs ()
export AFFINITY=""

bash ${1}/configs/DevOpsLiberty_Titans.sh ${1}
