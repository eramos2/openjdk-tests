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

## Print out the help information if all mandatory environment variables are not set
usage()
{
echo "
Usage:

To customize the use of this script use the following environment variables:

VERBOSE_MODE        - Prints all commands before they are executed.

NO_SETUP            - Liberty server creation is skipped if set to true.
                      If false, a new server will be created and the corresponding customized server.xml
                      and customized bootstrap.properties (if exists) files will overwrite the server's default.

SETUP_ONLY          - Only Liberty server creation and replacement of Liberty server default server.xml and bootstrap.properties (if available) is done.

JDK                 - Name of JDK build to use.

JDK_DIR             - Absolute path to directory where JDK builds are located.
                      Ex: if the path to a JDK's bin directory is /tmp/all_jdks/jdk8/sdk/bin
                      Then JDK=jdk8 and JDK_DIR=/tmp/all_jdks

JDK_OPTIONS         - JVM command line options

OPENJ9_JAVA_OPTIONS    - OpenJ9 Java options

PROFILING_TOOL      - Profiling Tool to Use (Example: 'jprof tprof', 'perf stat')

PETERFP             - Enable Peter's Footprint Tool (Default: false).
                      Gives a more detailed version of the footprint used, breaking it down so you can tell what component changed the footprint. Only needed for diagnosis when the footprint changes

WARM                - Number of warm runs

COLD                - Number of cold runs

WARMUP              - Number of warmup runs

COGNOS_INSTALL_DIR  - Installation directory for cognos

COGNOS_WAIT         - Seconds to wait for cognos to finish starting up (Default: 120)

REMOUNTSCRIPT       - Only required for AIX

LIBERTY_HOST        - Hostname for Liberty host machine

LAUNCH_SCRIPT       - Liberty script that can create, start, stop a server

SERVER_NAME         - The given name will be used to identify the Liberty server.

SERVER_XML          - Liberty server.xml configuration

AFFINITY            - CPU pinning command prefixed on the Liberty server start command.

SCENARIO            - Supported scenarios: AcmeAir, Cognos, DayTrader, DayTrader7, HugeEJB, HugeEJBApp, SmallServlet, TradeLite

APP_VERSION
                    - The specific DayTrader 3 application version used for all scenarios
                      involving this particular benchmark. (Default: daytrader3.0.10.1-ee6-src)

RESULTS_MACHINE     - Hostname for results storage machine

RESULTS_DIR         - Name of directory on Liberty host where results are temporarily stored

ROOT_RESULTS_DIR    - Absolute path of Liberty results directory on remote storage machine

"
}

echo "Inside sufp_docker_benchmark_test.sh"

TAG=full

echo "Found Liberty Release: ${RELEASE}"
echo "Found Build: ${BUILD}"
echo "JDK_LEVEL=${JDK_LEVEL}"
echo "Found Java Build: ${JAVA_BUILD}"
echo "Found Scenario: ${SCENARIO}"







echo "Running SUFT Tests"
echo "Current directory is:"
pwd

DOCKER_FILE="Dockerfile-daily"
echo "Creating Dockerfile=${DOCKER_FILE} for SCENARIO=${SCENARIO}"
echo "FROM openliberty/daily" >> ${DOCKER_FILE}
echo "COPY --chown=1001:0 ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/server.xml /config/server.xml" >> ${DOCKER_FILE} 
echo "COPY --chown=1001:0 ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/*.war /config/apps/" >> ${DOCKER_FILE}

echo "use following Dockerfile to build the image and run the container"
echo ${DOCKER_FILE}
cat ${DOCKER_FILE}
echo "Current working dir"
pwd
ls
docker ps
echo "Nuke Docker"
docker stop $(docker ps -a -q); docker rm $(docker ps -a -q)
  
for i in `seq 1 ${MEASUREMENT_RUNS}`
do
  #docker build -t acmeair-authservice -f ${DOCKER_FILE} --no-cache .
  docker build -t ${SCENARIO} -f ${DOCKER_FILE} --no-cache .
  #docker run -d acmeair-authservice
  docker run -d ${SCENARIO}
  CID=`docker ps | awk 'FNR == 2 {print}'| awk '{print $1}'`
  sleep 30
  echo "Get startup time results"

  echo "--get stop time"
  # normal
  time1=`docker exec ${CID} cat /logs/messages.log | grep smarter  | awk '{gsub("\\\\["," "); print $0}' | awk '{print $1 " " $2}' | awk '{gsub(","," "); print $0 " UTC"}' | rev | awk '{sub(":","."); print $0}' | rev`
  if [[ $(echo $time1 | grep -c liberty_message) == 1 ]]
  then
     #json
    time1=`docker exec ${CID} cat /logs/messages.log | grep smarter | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep ibm_datetime | awk '{gsub("\""," ");print $3}'`
  fi
  let stopMillis=`date "+%s%N" -d "$time1"`/1000000
     
  echo "--use docker log timestamp to get start time"
  time2=`docker exec ${CID} cat /logs/messages.log | grep launched | awk '{gsub("\\\[", " "); print $0}'| awk '{print $1 " " $2}' | awk '{gsub(",",","); print $0 " UTC"}' | rev | awk '{sub(":","."); print $0}' | awk '{gsub(",",""); print $0}' | rev`
  echo "time1: $time1 time2: $time2"  
  let startMillis=`date "+%s%N" -d "$time2"`/1000000
    
  echo "--get startup time"
  let startup=$((stopMillis - startMillis))
  echo "Startup=${startup}"
  echo "--get footprint"
  echo "Footprint=$(docker stats ${CID} --no-stream --format "table {{.MemUsage}}"| sed "1 d"| awk '{print substr($1, 1, length($1)-3)}')"

  docker stop $CID
  echo "Nuke Docker"
  docker stop $(docker ps -a -q); docker rm $(docker ps -a -q)
done

echo "Clean Docker"
docker stop $(docker ps -a -q); docker rm $(docker ps -a -q)

