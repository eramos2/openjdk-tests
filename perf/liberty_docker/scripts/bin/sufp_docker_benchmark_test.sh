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

#######################################################################################
#	STARTUP TIME, FOOTPRINT, FIRST RESPONSE, CPU USAGE UTILS - Helper methods that are sufp specific
#######################################################################################

##
## First Response scenario setup. Set strings for respString, and testTarget. Kill any zombie ping scripts on requestHost.
setFirstResponse()
{
    printf '%s\n' "
.--------------------------
| First Response Setup
"
  # Scenarios that do first response request
  local FR_SCENARIOS=("acmeair-micro" "acmeair-mono" "cdi-base" "cdi-fat" "cdi-one-jar-fat" "pingperf" "dt7" "dt8" "jaxrs-fat" "jenkins" "petclinic" "spring-1.5.6" "spring-2.1.1" "springboot-war" "tradelite7" "tradelite8")  
  
  timeToFirstRequest="false"
  firstResponseScript=/sufp/pingFirstResponse.sh
  cleanupScript=/sufp/cleanupScripts.sh

  if [[ " ${FR_SCENARIOS[@]} " =~ " ${SCENARIO} " ]];
  then
    timeToFirstRequest="true"
  fi

  echo "*** kill any zombie ping scripts on requestHost: ${LOAD_DRIVER} ***" 
  ssh ${LOAD_DRIVER} "${cleanupScript} ${firstResponseScript}"

  respString=""
  testTarget=""

  # Assign testTarget and respString accorging to current scenario
  case ${SCENARIO} in
    pingperf)
      testTarget="/pingperf/ping/greeting"
	    respString=" SystemOut "
      ;;
    acmeair-micro)
      testTarget="/"
	    respString="Complete List : MongoClientOptions"
      ;;
    acmeair-mono)
      testTarget="/rest/info/config/runtime"
	    respString="SRVE0242I.*acmeair-monolithic.*Initialization successful"
      ;;
    cdi-base|cdi-fat|cdi-one-jar-fat)
      testTarget="/meetings/rest/meetings"
	    respString="SRVE0242I.*meetings.*Initialization successful"
      ;;
    dt7|dt8)
      testTarget="/daytrader/servlet/PingServlet"
	    respString="SRVE0242I.*PingServlet.*Initialization successful"
      ;;
    jaxrs-fat)
      testTarget="/jaxrs-fat/rest/hello/sayHello"
	    respString="SRVE0242I.*jaxrs-fat.*Initialization successful"
      ;;
    jenkins)
      testTarget="/jenkins/"
	    respString="SRVE0242I.*jenkins.*Initialization successful"
      ;;
    petclinic)
      testTarget="/petclinic/"
	    respString="SRVE0242I.*petclinic.*welcome.jsp.*Initialization successful"
      ;;
    spring-1.5.6|spring-2.1.1)
      testTarget="/"
	    respString="SRVE0242I.*authservice-springboot.*Initialization successful"
      ;;
    springboot-war)
      testTarget="/spring-petclinic/"
	    respString="SRVE0242I.*spring-petclinic.*Initialization successful"
      ;;
    tradelite7|tradelite8)
      testTarget="/tradelite/servlet/PingServlet"
	    respString="SRVE0242I.*PingServlet.*Initialization successful"
      ;;
    *) ;;
  esac

STARTED_STRING=" is ready to run a smarter"
  if [[ -z $timeToFirstRequest ]] ; then
	  echo -e "\n ****  measuring startup with config  ${SCENARIO}  **** \n"
	  echo -e "        STARTED_STRING: '${STARTED_STRING}' \n"
  else
	  echo -e "\n ****  measuring first response with app  ${SCENARIO}  ****\n"
	  echo -e "        first response string: \"$respString\"  "
  fi

}

 # Import the common utilities needed to run this benchmark
. "$(dirname $0)"/common_utils.sh

echo "Inside sufp_docker_benchmark_test.sh"

TAG=full

testHost=`hostname`
testPort=9080

echo "Found Scenario: ${SCENARIO}"
echo "Running SUFT Tests"
echo "Current directory is:"
pwd


DOCKER_FILE="Dockerfile-daily"
echo "Creating Dockerfile=${DOCKER_FILE} for SCENARIO=${SCENARIO} on LIBERTY_VERSION=${LIBERTY_VERSION}"
## Check if we are running liberty Websphere or Open Liberty Docker image
echo 
if [[ "${LIBERTY_VERSION}" == "WL" ]]; then
  echo "FROM websphereliberty/daily" >> ${DOCKER_FILE}
else
  echo "FROM openliberty/daily" >> ${DOCKER_FILE}
fi

echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/server.xml /config/server.xml" >> ${DOCKER_FILE} 
#Check if war|ear file exist for copy
echo "Checking war file"
echo "${TEST_RESROOT}"
ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/
echo "$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .war)"

if [ ! -z $(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .war) ];
then
  echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .war) /config/apps/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .war)" >> ${DOCKER_FILE}
fi
if [ ! -z $(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .ear) ];
then
  echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .ear) /config/apps/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .ear)" >> ${DOCKER_FILE}
fi
if [ ! -z $(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .jar) ];
then
  echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .jar) /config/apps/$(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO}/ | grep .jar)" >> ${DOCKER_FILE}
fi

echo "EXPOSE 27017" >> ${DOCKER_FILE}
echo "EXPOSE 9080" >> ${DOCKER_FILE}
echo "ENV MONGO_HOST=titans17" >> ${DOCKER_FILE}

if [ ! -z $(ls ${TEST_RESROOT}/scripts/sufp/apps/${SCENARIO} | grep resources) ];
then
  echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/resources /config/apps/resources" >> ${DOCKER_FILE}
fi

#echo "COPY --chown=1001:0 /opt/db2jars /opt/db2jars" >> ${DOCKER_FILE}

#Edit server.xml to point to app location
serverXML="scripts/sufp/apps/${SCENARIO}/server.xml"
sed -i "s|\"/sufp/apps/${SCENARIO}|\"/config/apps|g" ${TEST_RESROOT}/${serverXML}
sed -i "s|\"/opt/db2jars|\"/opt/db2jars|g" ${TEST_RESROOT}/${serverXML}
if [[ `echo ${SCENARIO} | grep spring ` ]]; 
then
	echo "RUN mkdir -p /config/dropins/spring" >> ${DOCKER_FILE}
  echo "COPY --chown=1001:0 scripts/sufp/apps/${SCENARIO}/*.jar /config/dropins/spring" >> ${DOCKER_FILE}
fi

echo "use following Dockerfile to build the image and run the container"
echo ${DOCKER_FILE}
cat ${DOCKER_FILE}
echo "Current working dir"
pwd
ls
docker ps

setFirstResponse

  
for i in `seq 1 ${MEASUREMENT_RUNS}`
do
  nukeDocker
  #convert scenario name to lowercase so it can be passed as the docker container tag 
  scenarioTag=`echo "${SCENARIO}" | awk '{print tolower($0)}'`
  docker build -t ${scenarioTag} -f ${DOCKER_FILE} --no-cache ${TEST_RESROOT}
  echo "docker build -t ${scenarioTag} -f ${DOCKER_FILE} --no-cache ${TEST_RESROOT}"
  
  # Start first response ping script
  if [[ ! -z ${timeToFirstRequest} ]];
  then
	  ( ssh ${LOAD_DRIVER} $firstResponseScript $testHost $testPort $testTarget ) &
  fi
  
  docker run -p 9080:9080 -d ${scenarioTag} 
  echo "docker run -p 9080:9080 -d ${scenarioTag} "
  #Get Container ID
  CID=`docker ps | awk 'FNR == 2 {print}'| awk '{print $1}'`
  sleep 30

if [[ $i == 1 ]]
then
  if [[ "${LIBERTY_VERSION}" == "WL" ]]; 
  then
    RELEASE=`docker logs ${CID} | grep "WebSphere Application Server" | awk '{print $6}' | awk '{gsub("/"," "); print $1}'`
    BUILD=`docker logs ${CID} | grep "WebSphere Application Server" | awk '{print $6}' | awk '{gsub("/"," "); print $2}'  | awk '{gsub("\\\.", " "); print $4}' | awk '{print substr($1, 1, length($1)-1)}'`
  else
    RELEASE_CUR=`docker logs ${CID} 2>/dev/null | grep "Open Liberty" | awk '{print $5}' | awk '{gsub("/"," "); print $1}'`
	  BUILD_CUR=`docker logs ${CID} 2>/dev/null | grep "Open Liberty" | awk '{print $5}' | awk '{gsub("/"," "); print $2}'  | awk '{gsub("\\\.", " "); print $4}' | awk '{print substr($1, 1, length($1)-1)}'`
  fi
	JDK_LEVEL_CUR=`docker exec ${CID} java -version 2>&1 | tr -d '\n'`
	echo "Found ${LIBERTY_VERSION} Release: ${RELEASE_CUR}"
	echo "Found Build: ${BUILD_CUR}"
	echo "JDK_LEVEL=${JDK_LEVEL_CUR}"
  fi
  
  echo "Get startup time results"
  echo "--get stop time"
  # normal
  time1=`docker exec ${CID} cat /logs/messages.log | grep "${STARTED_STRING}" | awk '{gsub("\\\["," "); print $0}' | awk '{print $1 " " $2}' | awk '{gsub(","," "); print $0 " UTC"}' | rev | awk '{sub(":","."); print $0}' | rev`
  if [[ $(echo $time1 | grep -c liberty_message) == 1 ]]
  then
    #json
    time1=`docker exec ${CID} cat /logs/messages.log | grep "${STARTED_STRING}" | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | grep ibm_datetime | awk '{gsub("\""," ");print $3}'`
  fi
  let stopMillis=`date "+%s%N" -d "$time1"`/1000000
     
  echo "--use docker log timestamp to get start time"
  time2=`docker exec ${CID} cat /logs/messages.log | grep launched | awk '{gsub("\\\[", " "); print $0}'| awk '{print $1 " " $2}' | awk '{gsub(",",","); print $0 " UTC"}' | rev | awk '{sub(":","."); print $0}' | awk '{gsub(",",""); print $0}' | rev`
  echo "time1: $time1 time2: $time2"  
  let startMillis=`date "+%s%N" -d "$time2"`/1000000
    
  echo "--get startup time"
  let startup=$((stopMillis - startMillis))
  echo "Startup time: ${startup}"

  echo "--get first response time"
  respTime=""
  if [[ ! -z ${timeToFirstRequest} ]];
  then
    RESP_TIME=""
    while [[ -z $RESP_TIME ]];
    do
      resp=`docker exec ${CID} cat /logs/messages.log | grep "${respString}" | awk '{gsub("\\\["," "); print $0}' | awk '{print $1 " " $2}' | awk '{gsub(","," "); print $0 " UTC"}' | rev | awk '{sub(":","."); print $0}' | rev`
      if [[ ! -z $resp ]];
      then
        RESP_TIME=`echo $(($(date "+%s%N" -d "$resp")/1000000))`
        resptime=`expr $RESP_TIME - $startMillis`
      else
        ## TODO - NEED to fix this so it does it for a finite amount of iterations an abort after it fails, to avoid an infinite loop
        sleep 2
      fi
    done
  fi
  if [[ ! -z ${timeToFirstRequest} ]];
  then
    echo "First Response: ${resptime}"
  else
    echo -e "First Response: n/a"
  fi

  echo "--get footprint"
  echo "Footprint (mb)=$(docker stats ${CID} --no-stream --format "table {{.MemUsage}}"| sed "1 d"| awk '{print substr($1, 1, length($1)-3)}')"

  echo "app: ${SCENARIO}"
  docker stop $CID
  #nukeDocker
done



