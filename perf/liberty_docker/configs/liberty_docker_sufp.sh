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

export JDK="j2sdk-image"
echo "JDK=${JDK}"

export JDK_DIR="${TEST_JDK_HOME}/.."
echo "JDK_DIR=${JDK_DIR}"

export LIBERTY_DOCKER_DIR=${TEST_JDK_HOME}/../../jvmtest/perf/liberty_docker
echo "LIBERTY_DOCKER_DIR=${LIBERTY_DOCKER_DIR}"

export SCENARIO="${1}"
echo "SCENARIO=${SCENARIO}"

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
#export SCENARIO="DayTrader7"
export SERVER_NAME="LibertySUDTServer-$JDK"
export PETERFP="false"
export RESULTS_MACHINE="lowry1"
export RESULTS_DIR="libertyResults"
export LIBERTY_HOST="$(hostname)"
export LAUNCH_SCRIPT="server"
export LIBERTY_BINARIES_DIR="$1/libertyBinaries"
#export LIBERTY_VERSION="openliberty-19.0.0.4"
export APP_VERSION="daytrader-ee7"
export WLP_SKIP_MAXPERMSIZE="1"

export MP_RELEASES=(microProfile-3.3)
export MP_RELEASE=microProfile-3.3
export APP_HOST=titans16
export PORT=80
export PROTOCOL=http
export DB_HOST=smith3
export DRIVER_HOST=trinity10
export ITERATIONS=1
export JMETER_HOME=/opt/apache-jmeter-2.13
export JMETER_THREADS=50
export MEASUREMENT_DURATION=180
export MEASUREMENT_RUNS=${MEASUREMENT_RUNS}
export OVERALL_RESULTS_DIR=/opt/docker-results
export BUILD=${LIBERTY_BUILD_LEVEL}
export BASE_TAG=java8-openj9
export OPENLIBERTY=true
export OPENLIBERTY_IMAGE=kernel
#Tests
export DO_THROUGHPUT_TESTS=false
export DO_SUFT_TESTS=true

#TODO: Need to soft-code these configs. Need to add various affinity tools in the perf pre-reqs ()
export AFFINITY=""

bash ${TEST_RESROOT}/scripts/bin/sufp_docker_benchmark_test.sh
