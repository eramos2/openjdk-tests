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

echo "Inside sufp_docker_benchmark.sh"

TAG=full

echo "Found Liberty Release: ${RELEASE}"
echo "Found Build: ${BUILD}"
echo "JDK_LEVEL=${JDK_LEVEL}"
echo "Found Java Build: ${JAVA_BUILD}"
echo "Found Scenario: ${SCENARIO}"

echo "Get Latest ${MP_RELEASE} code from github"
DOCKER_AUTOMATED_GIT_DIR="${LIBERTY_BINARIES_DIR}/docker-automated/git"
rm -rf ${DOCKER_AUTOMATED_GIT_DIR}
mkdir -p ${DOCKER_AUTOMATED_GIT_DIR}
cd ${DOCKER_AUTOMATED_GIT_DIR}

case ${MP_RELEASE} in

microProfile-1.0)
 BRANCH="-b microprofile-1.0" 
 ;;
microProfile-1.4)
 BRANCH="-b microprofile-1.4"
 ;;
microProfile-2.0)
 BRANCH="-b microprofile-2.0"
 ;;
microProfile-2.2)
 BRANCH="-b microprofile-2.2"
 ;;
microProfile-3.0)
 BRANCH="-b microprofile-3.0"
 ;;
microProfile-3.2)
 BRANCH="-b microprofile-3.2"
 ;;
microProfile-3.3)
 BRANCH=""
 ;;
esac

echo "Clone ${BRANCH}"
git clone ${BRANCH} https://github.com/BluePerf/acmeair-mainservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-authservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-bookingservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-customerservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-flightservice-java.git

echo "Build java"
cd acmeair-mainservice-java
mvn clean package

cd ../acmeair-authservice-java
mvn clean package

cd ../acmeair-bookingservice-java
mvn clean package

cd ../acmeair-customerservice-java
mvn clean package

cd ../acmeair-flightservice-java
mvn clean package

cd ..

cp ${LIBERTY_DOCKER_DIR}/scripts/resource/docker-compose-${MP_RELEASE}.yml ${DOCKER_AUTOMATED_GIT_DIR}/acmeair-mainservice-java/docker-compose.yml

# hack for now, may nee dto update java.security file occasionally
if [[ "${2}" == *true* ]] 
then

  echo " enabling jce plus"
  cp ${LIBERTY_DOCKER_DIR}/scripts/resource/java.security acmeair-authservice-java/
  cp ${LIBERTY_DOCKER_DIR}/scripts/resource/java.security acmeair-bookingservice-java/
  cp ${LIBERTY_DOCKER_DIR}/scripts/resource/java.security acmeair-customerservice-java/

  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-authservice-java/Dockerfile-daily
  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-bookingservice-java/Dockerfile-daily
  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-customerservice-java/Dockerfile-daily

fi

if [[ ${DO_SUFT_TESTS} == "true" ]]
then 
  echo "Running SUFT Tests"
  DOCKER_FILE=$(cat ${DOCKER_AUTOMATED_GIT_DIR}/acmeair-mainservice-java/docker-compose.yml | grep -A 2 acmeair-authservice-java | grep dockerfile | awk '{print $2}')
  
  sleep 5
  echo "use Dockerfile to build image and run the container"
  cd ${DOCKER_AUTOMATED_GIT_DIR}/acmeair-authservice-java/
  echo "Current working dir"
  pwd
  ls
  docker ps
  echo "Nuke Docker"
  docker stop $(docker ps -a -q); docker rm $(docker ps -a -q)
  
  for i in 1 2 3 4 5
  do
    docker build -t acmeair-authservice -f ${DOCKER_FILE} --no-cache .
    docker run -d acmeair-authservice
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
fi
