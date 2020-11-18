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

# Print out the help information if all mandatory environment variables are not set
usage()
{
	echo "
Usage:

To customize the use of this script use the following environment variables:

DEST							- Location of Liberty Test Material
LIBERTY_DEP_CACHE_LOCATION		- Cache with Liberty Dependencies

"
}

# Environment variables setup. Terminate script if a mandatory env variable is not set
checkAndSetEnvVars()
{
	printf '%s\n' "
.--------------------------
| Environment Setup
"

    if [ -z "${DEST}" ]; then
        echo "DEST not set. Defaulting to current directory"
        DEST="."
    fi
    if [ -z "${LIBERTY_DEP_CACHE_LOCATION}" ]; then
        echo "LIBERTY_DEP_CACHE_LOCATION not set. Defaulting to current directory"
        LIBERTY_DEP_CACHE_LOCATION="."
    fi
   
	echo "DEST=${DEST}"
	echo "LIBERTY_DEP_CACHE_LOCATION=${LIBERTY_DEP_CACHE_LOCATION}"	
}

echoAndRunCmd()
{
	echo "$1"
	$1
}

populateDatabase()
{
	printf '%s\n' "
.--------------------------
| Populate Database
"
	
	DB_FILE="${DEST}/libertyBinaries/${BM_VERSION}/usr/shared/resources/data/tradedb7/service.properties"
	if [ -e "${DB_FILE}" ]; then
		echo "${DB_FILE} exists. Not configuring database."
	else
		echo "${DB_FILE} doesn't exist. Configuring database."
		export DB_SETUP="1"
		bash ${DEST}/configs/dt7_throughput.sh ${DEST}
		unset DB_SETUP
	fi
}

nukeDocker()
{
	docker stop $(docker ps -a -q); docker rm $(docker ps -a -q)
}

JMETER_DEPENDENCIES_URL=(
	"https://github.com/maciejzaleski/JMeter-WebSocketSampler/releases/download/version-1.0.2/JMeterWebSocketSampler-1.0.2-SNAPSHOT.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/websocket-server/9.1.1.v20140108/websocket-server-9.1.1.v20140108.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-io/9.1.1.v20140108/jetty-io-9.1.1.v20140108.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-util/9.1.1.v20140108/jetty-util-9.1.1.v20140108.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/websocket-api/9.1.1.v20140108/websocket-api-9.1.1.v20140108.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/websocket-client/9.1.1.v20140108/websocket-client-9.1.1.v20140108.jar"
    "https://repo1.maven.org/maven2/org/eclipse/jetty/websocket/websocket-common/9.1.1.v20140108/websocket-common-9.1.1.v20140108.jar"
)

downloadJmeterDependencies()
{
	printf '%s\n' "
.--------------------------
| Downloading JMeter dependencies
"

 	echoAndRunCmd "cd ${JMETER_LOCATION}/lib/ext"
 	
	for i in "${JMETER_DEPENDENCIES_URL[@]}"; do

		DEP_NAME=${i}
		CURL_CMD="curl -OLks ${DEP_NAME}"
		
		echoAndRunCmd "${CURL_CMD}"

    done

}

unsetVars()
{	
	unset APP_URL APP_ARCHIVE EXTRACT_ORIGINAL_NAME EXTRACT_NEW_NAME APP_DEST GITHUB_OAUTH_TOKEN
}

downloadDepencies()
{	
	printf '%s\n' "
.--------------------------
| Downloading Dependencies ${EXTRACT_NEW_NAME}
"
   
	echo "APP_URL=${APP_URL}"
	echo "APP_ARCHIVE=${APP_ARCHIVE}"
	echo "EXTRACT_ORIGINAL_NAME=${EXTRACT_ORIGINAL_NAME}"	
	echo "EXTRACT_NEW_NAME=${EXTRACT_NEW_NAME}"
	echo "APP_DEST=${APP_DEST}"
	
	echoAndRunCmd "mkdir -p ${APP_DEST}"
	
	echoAndRunCmd "cd ${LIBERTY_DEP_CACHE_LOCATION}"
	
	if [ -e "${APP_DEST}/${EXTRACT_NEW_NAME}" ]; then
		echo "${APP_DEST}/${EXTRACT_NEW_NAME} exists in Dest. Hence, not downloading it."
	else		
		echo "${APP_DEST}/${EXTRACT_NEW_NAME} doesn't exist in Dest."	
		
		if [ -e "${APP_ARCHIVE}" ]; then
			echo "${LIBERTY_DEP_CACHE_LOCATION}/${APP_ARCHIVE} exists in Cache. Hence, not downloading it."
		else
			echo "${LIBERTY_DEP_CACHE_LOCATION}/${APP_ARCHIVE} doesn't exist in Cache. Hence, downloading it."
			if [ -z "${GITHUB_OAUTH_TOKEN}" ]; then
				echo "No authentication needed"
				CURL_CMD="curl -OLk ${APP_URL}"
			else 
			    echo "Use GITHUB_OAUTH_TOKEN to authenticate"
				CURL_CMD="curl -OLk -H \"Authorization: token ${GITHUB_OAUTH_TOKEN}\" ${APP_URL}"
			fi
			 
	
			echoAndRunCmd "${CURL_CMD}"		
		fi
		
		if [ "${APP_ARCHIVE}" != "${EXTRACT_NEW_NAME}" ]; then
			echo "${APP_ARCHIVE} requires extraction."
			echoAndRunCmd "unzip -oq ${APP_ARCHIVE} -d ${APP_DEST}"
			
			if [ "${EXTRACT_NEW_NAME}" != "${EXTRACT_ORIGINAL_NAME}" ]; then
				echo "EXTRACT_NEW_NAME (${EXTRACT_NEW_NAME}) is not equal to EXTRACT_ORIGINAL_NAME (${EXTRACT_ORIGINAL_NAME}). Hence, need to rename the directory."
				echoAndRunCmd "mv ${APP_DEST}/${EXTRACT_ORIGINAL_NAME} ${APP_DEST}/${EXTRACT_NEW_NAME}"
			else
				echo "EXTRACT_NEW_NAME is equal to EXTRACT_ORIGINAL_NAME (${EXTRACT_ORIGINAL_NAME}). Hence, no need to rename directory."	
			fi
		
		else
			echo "${APP_ARCHIVE} doesn't require extraction."
			echoAndRunCmd "cp ${APP_ARCHIVE} ${APP_DEST}"
		fi
	fi 	
}

OS=$(uname)
echo "OS=${OS}"
ARCH=$(uname -m)
echo "ARCH=${ARCH}"

if [ "${OS}" = "Linux" ] && [ "${ARCH}" = "x86_64" ]; then
	echo "Configuring Liberty since OS=${OS} and ARCH=${ARCH}, which is the only platform tested so far."
else
	echo "Exiting without configuring Liberty since OS=${OS} and ARCH=${ARCH}. Linux x86_64 is the only platform tested so far."
	exit	
fi
	
checkAndSetEnvVars

echoAndRunCmd "mkdir -p ${DEST} ${LIBERTY_DEP_CACHE_LOCATION}"


##########################

unsetVars
APP_URL="https://public.dhe.ibm.com/ibmdl/export/pub/software/openliberty/runtime/release/2019-04-19_0642/openliberty-19.0.0.4.zip"
APP_ARCHIVE="$(basename ${APP_URL})"
EXTRACT_ORIGINAL_NAME="wlp"
EXTRACT_NEW_NAME="openliberty-19.0.0.4"
APP_DEST="${DEST}/libertyBinaries"
downloadDepencies

BM_VERSION=${EXTRACT_NEW_NAME}

##########################

unsetVars
APP_URL="https://github.com/WASdev/sample.daytrader7/releases/download/v1.2/daytrader-ee7.ear"
APP_ARCHIVE="$(basename ${APP_URL})"
EXTRACT_ORIGINAL_NAME=${APP_ARCHIVE}
EXTRACT_NEW_NAME=${EXTRACT_ORIGINAL_NAME}
APP_DEST="${DEST}/libertyBinaries/${BM_VERSION}/usr/shared/apps/webcontainer"
downloadDepencies

##########################

unsetVars
APP_URL="https://github.com/OpenLiberty/ci.docker.daily/archive/master.zip"
APP_ARCHIVE="$(basename ${APP_URL})"
EXTRACT_ORIGINAL_NAME=${APP_ARCHIVE}
EXTRACT_NEW_NAME="ci.docker.daily-master"
APP_DEST="${DEST}/OL-docker-images"
downloadDepencies

##########################

unsetVars
APP_URL="https://github.ibm.com/was-docker/daily-liberty-images/archive/master.zip"
APP_ARCHIVE="$(basename ${APP_URL})"
EXTRACT_ORIGINAL_NAME=${APP_ARCHIVE}
EXTRACT_NEW_NAME="daily-liberty-images-master"
APP_DEST="${DEST}/CL-docker-images"
GITHUB_OAUTH_TOKEN=${GITHUB_OAUTH_TOKEN}
downloadDepencies

#TODO
#WL- only works with latest cuurently
#OL - only uses kernel image currently, may nee dto add full.
##Websphere Liberty

USERNAME=wasperf@us.ibm.com
PASSWORD=UmVncmVzc2lvbjZQQHRyb2w=
BUILD=latest
BASE_TAG=java8-ibmjava

OPENLIBERTY=false

DO_THROUGHPUT_TESTS=true
DO_SUFT_TESTS=true
echo "Clean Docker" 
nukeDocker
echo "BUILD=${BUILD}"
echo "IMAGE=${OPENLIBERTY_IMAGE}"
echo "BASE_TAG=${BASE_TAG}"
echo "Current directory=$(dirname $0)"
$(dirname $0)/websphere-liberty/build-daily-images-wasperf.sh ${USERNAME} ${DECODED_PASSWORD} ${BUILD} ${BASE_TAG}

### Open Liberty
# Set release and docker tag to pull
echo "Clean Docker" 
nukeDocker
export BUILD=latest
export BASE_TAG=java8-openj9
export OPENLIBERTY_IMAGE=kernel
echo "BUILD=${BUILD}"
echo "IMAGE=${OPENLIBERTY_IMAGE}"
echo "BASE_TAG=${BASE_TAG}"
echo "Current directory=$(dirname $0)"
$(dirname $0)/open-liberty/buildAll_wasperf.sh ${BUILD} ${BASE_TAG}





getLibertyInfo()
{
  

  sleep 5

  # Yikes this is ugly....
#   if [[ ${OPENLIBERTY} == "false" ]]
#   then
    TAG=full
    CID=`docker run -d websphere-liberty:${TAG}`
    RELEASE=`docker logs ${CID} | grep "WebSphere Application Server" | awk '{print $6}' | awk '{gsub("/"," "); print $1}'`
	docker stop ${CID} > /dev/null
	CID=`docker run -d websphereliberty/daily`
    sleep 5
	BUILD=docker logs ${CID} | grep "WebSphere Application Server" | awk '{print $6}' | awk '{gsub("/"," "); print $2}'  | awk '{gsub("\\.", " "); print $4}' | awk '{print substr($1, 1, length($1)-1)}'
    docker stop ${CID} > /dev/null
	echo "Found Websphere Liberty Release: ${RELEASE}"
	echo "Found Build: ${BUILD}"
	echo "JDK_LEVEL=${JDK_LEVEL}"
	echo "Found Java Build: ${JAVA_BUILD}"
	echo "Found Scenario: ${SCENARIO}"
	echo "Found Build: ${BUILD}"
	nukeDocker
#   else
    CID=`docker run -d openliberty/daily`
    RELEASE=`docker logs ${CID} 2>/dev/null | grep "Open Liberty" | awk '{print $5}' | awk '{gsub("/"," "); print $1}'`
	BUILD=`docker logs ${CID} 2>/dev/null | grep "Open Liberty" | awk '{print $5}' | awk '{gsub("/"," "); print $2}'  | awk '{gsub("\\.", " "); print $4}' | awk '{print substr($1, 1, length($1)-1)}'`
    docker exec ${CID} java -version 2>&1 | tr -d '\n'
	docker stop ${CID} > /dev/null
	echo "Found Open Liberty Release: ${RELEASE}"
	echo "Found Build: ${BUILD}"
	echo "JDK_LEVEL=${JDK_LEVEL}"
	echo "Found Java Build: ${JAVA_BUILD}"
	echo "Found Scenario: ${SCENARIO}"
	echo "Found Build: ${BUILD}"
	nukeDocker
#   fi
}
getLibertyInfo


##CREATE BUILD_RESULTS_DIR
#DATE=$(date +%Y%m%d-%H%M%S)
#BUILD_RESULTS_DIR=${OVERALL_RESULTS_DIR}/${BUILD}-${DATE}
#mkdir -p ${BUILD_RESULTS_DIR}

#echo "Results Dir: " ${BUILD_RESULTS_DIR}
#########################

# unsetVars
# APP_URL="http://archive.apache.org/dist/db/derby/db-derby-10.10.1.1/db-derby-10.10.1.1-lib.zip"
# APP_ARCHIVE="$(basename ${APP_URL})"
# EXTRACT_ORIGINAL_NAME="db-derby-10.10.1.1-lib"
# EXTRACT_NEW_NAME=${EXTRACT_ORIGINAL_NAME}
# APP_DEST="${DEST}"
# downloadDepencies

# DERBY_FILE_LOCATION="${DEST}/libertyBinaries/${BM_VERSION}/usr/shared/resources/derby/"
# echoAndRunCmd "mkdir -p ${DERBY_FILE_LOCATION}"
# echoAndRunCmd "cp ${APP_DEST}/${EXTRACT_NEW_NAME}/lib/derby.jar ${DERBY_FILE_LOCATION}"

##########################

# unsetVars
# APP_URL="https://github.com/WASdev/sample.daytrader7/archive/v1.2.zip"
# APP_ARCHIVE="$(basename ${APP_URL})"
# EXTRACT_ORIGINAL_NAME="sample.daytrader7-1.2"
# EXTRACT_NEW_NAME=${EXTRACT_ORIGINAL_NAME}
# APP_DEST="${DEST}"
# downloadDepencies

# JMX_FILE_LOCATION="${DEST}/scripts/resource/client_scripts"
# echoAndRunCmd "mkdir -p ${JMX_FILE_LOCATION}"
# echoAndRunCmd "cp ${APP_DEST}/${EXTRACT_NEW_NAME}/jmeter_files/daytrader7.jmx ${JMX_FILE_LOCATION}"

##########################

# unsetVars
# APP_URL="https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-3.3.zip"
# APP_ARCHIVE="$(basename ${APP_URL})"
# EXTRACT_ORIGINAL_NAME="apache-jmeter-3.3" 
# EXTRACT_NEW_NAME=${EXTRACT_ORIGINAL_NAME}
# APP_DEST="${DEST}/JMeter"
# downloadDepencies

# JMETER_LOCATION="${APP_DEST}/${EXTRACT_NEW_NAME}"
# downloadJmeterDependencies

##########################

#populateDatabase

##########################


