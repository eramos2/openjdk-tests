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
	unset APP_URL APP_ARCHIVE EXTRACT_ORIGINAL_NAME EXTRACT_NEW_NAME APP_DEST AUTH_NEEDED
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
			if [ -z "${AUTH_NEEDED}" ]; then
				echo "No authentication needed"
				CURL_CMD="curl -OLk ${APP_URL}"
			elif [ -z "${AUTH_TOKEN}" ]; then
				echo "Use AUTH_USERNAME AND AUTH_PASSWORD to authenticate - ${AUTH_USERNAME}:${AUTH_PASSWORD}"
				CURL_CMD="curl -OL -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${APP_URL}"
			else 
			    echo "Use AUTH_TOKEN to authenticate - ${AUTH_TOKEN}"
				PARTIAL_CURL_CMD="curl -OL -H \"Authorization: token ${AUTH_TOKEN}\" \"${APP_URL}\""
				CURL_CMD="eval $PARTIAL_CURL_CMD"
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

getLibertyLatestBuildLabel()
{
	printf '%s\n' "
.--------------------------
| Get Latest Build Label URL and set LIBERTYFS_BUILD_URL
"

	# Get build label from last.good.build.label Ex -> "cl210120201123-1900-_uucZEC21EeuXe4FTUa5Giw"
	local LATEST_LABEL_RELEASE=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_URL}/release/last.good.build.label`
	local LATEST_LABEL_RELEASE2=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_URL}/release2/last.good.build.label`

	# Get the latest build label from release or release2
	if [[ "${LATEST_LABEL_RELEASE}" > "${LATEST_LABEL_RELEASE2}" ]]; then
    	echo "${LATEST_LABEL_RELEASE} greater than ${LATEST_LABEL_RELEASE2} - using ${LIBERTYFS_URL}/release/${LATEST_LABEL_RELEASE} URL"
		LIBERTYFS_BUILD_URL="${LIBERTYFS_URL}/release/${LATEST_LABEL_RELEASE}"
	else
    	echo "${LATEST_LABEL_RELEASE2} greater than ${LATEST_LABEL_RELEASE} - using ${LIBERTYFS_URL}/release2/${LATEST_LABEL_RELEASE2} URL"
		LIBERTYFS_BUILD_URL="${LIBERTYFS_URL}/release2/${LATEST_LABEL_RELEASE2}"
	fi

	if [[ -z ${LIBERTYFS_BUILD_URL} ]]; then
		echo "Exiting without configuring Liberty since a latest build was not found in ${LIBERTYFS_URL}/release or ${LIBERTYFS_URL}/release2"
		exit
	fi

}

searchLibertyBuild()
{
	printf '%s\n' "
.--------------------------
| Search for the given Liberty BUILD on libertyfs release/release2 and set LIBERTYFS_BUILD_URL
"

	# Search for a build match on release or release2. Match looks like example bellow:
	# <tr><td valign="top"><img src="/icons/folder.gif" alt="[DIR]"></td><td><a href="cl210220210121-1100-_hXbe0FvPEeuM3vrL9EeJlQ/">cl210220210121-1100-_hXbe0FvPEeuM3vrL9EeJlQ/</a></td><td align="right">2021-01-26 10:24  </td><td align="right">  - </td><td>&nbsp;</td></tr>
	local BUILD_LABEL_RELEASE=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_URL}/release | grep "${LIBERTY_BUILD_LEVEL}"`
	local BUILD_LABEL_RELEASE2=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_URL}/release2/ | grep "${LIBERTY_BUILD_LEVEL}"`
	local BUILD_LABEL
	if [[ ! -z "${BUILD_LABEL_RELEASE}" ]]; then
		echo "Found ${LIBERTY_BUILD_LEVEL} in ${LIBERTYFS_URL}/release"
		echo "${BUILD_LABEL_RELEASE}"
	    BUILD_LABEL=`echo ${BUILD_LABEL_RELEASE} | grep -oE "${LIBERTY_BUILD_LEVEL}.*/\"" | sed 's/\/"//'`
		LIBERTYFS_BUILD_URL="${LIBERTYFS_URL}/release/${BUILD_LABEL}"
	elif [[ ! -z "${BUILD_LABEL_RELEASE2}" ]]; then
		echo "Found ${LIBERTY_BUILD_LEVEL} in ${LIBERTYFS_URL}/release2"
		echo "${BUILD_LABEL_RELEASE2}"
	    BUILD_LABEL=`echo ${BUILD_LABEL_RELEASE2} | grep -oE "${LIBERTY_BUILD_LEVEL}.*/\"" | sed 's/\/"//'`
		LIBERTYFS_BUILD_URL="${LIBERTYFS_URL}/release2/${BUILD_LABEL}"
	else
		echo "Exiting without configuring Liberty since ${LIBERTY_BUILD_LEVEL} was not found in ${LIBERTYFS_URL}/release or ${LIBERTYFS_URL}/release2"
		exit
	fi

}

getLibertyBuildDetails()
{
	printf '%s\n' "
.--------------------------
| Gather Liberty Build Details (Build Label, Websphere and Open Liberty Builds URL)
"

	# Get Liberty Latest Good Build 
	
 	LIBERTY_BUILD_LABEL=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_URL}/last.good.build.label`
 	
	for i in "${JMETER_DEPENDENCIES_URL[@]}"; do

		DEP_NAME=${i}
		CURL_CMD="curl -OLks ${DEP_NAME}"
		
		echoAndRunCmd "${CURL_CMD}"

    done

}

OS=$(uname)
echo "OS=${OS}"
ARCH=$(uname -m)
echo "ARCH=${ARCH}"

if [ "${OS}" != "Darwin" ] && [ "${ARCH}" != "aarch64" ]; then
	echo "Configuring Liberty since it's a tested platform: OS=${OS} and ARCH=${ARCH}"
else
	echo "Exiting without configuring Liberty since it's an untested platform: OS=${OS} and ARCH=${ARCH}"
	exit	
fi
	
checkAndSetEnvVars

echoAndRunCmd "mkdir -p ${DEST} ${LIBERTY_DEP_CACHE_LOCATION}"

# REPO - https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/cl210220210125-1100-_GAq8QF70Eeu-m6gcHvZdzA or https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release2/
# https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/last.good.build.html or https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release2/last.good.build.html
# CHECK IF LATEST BUILD IS DESIRED
LIBERTYFS_URL=https://${LIBERTY_BUILD_REPO}/liberty/dev/${LIBERTY_BUILD_STREAM}
echo "LIBERTYFS_URL=${LIBERTYFS_URL}"
if [[ "${LIBERTY_BUILD_LEVEL}" == "latest" ]]; then
	getLibertyLatestBuildLabel
	# Get the build from LIBERTYFS_BUILD_URL so we can use it for WL_ZIP - https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/cl210220210125-1100-_GAq8QF70Eeu-m6gcHvZdzA -> cl210220210125-1100
	LIBERTY_BUILD_LEVEL=`echo ${LIBERTYFS_BUILD_URL} | sed 's/^.*\///' | sed 's/-_.*//'`
else
	searchLibertyBuild
fi

# Download WL and OL from LIBERTYFS_BUILD_URL - Ex: https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/cl210220210125-1100-_GAq8QF70Eeu-m6gcHvZdzA
# To download OL https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/[BUILD LABEL]/fe/cl210220210125-1100.47.linux/linux/zipper/externals/installables/ and search for openliberty-all there 
echo "LIBERTYFS_BUILD_URL=${LIBERTYFS_BUILD_URL}"
echo "LIBERTY_BUILD_LEVEL=${LIBERTY_BUILD_LEVEL}"
FE_OL_URL=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_BUILD_URL}/fe/ | grep -oE "href=\"${LIBERTY_BUILD_LEVEL}.*\.linux/\"" | sed 's/\/"//' | sed 's/href="//'`
INSTALLABLES_OL_URL="${LIBERTYFS_BUILD_URL}/fe/${FE_OL_URL}/linux/zipper/externals/installables"
OL_ZIP=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${INSTALLABLES_OL_URL}/ | grep -oE "openliberty-all.*.zip\"" | sed 's/"//'`
# To download WL search for wlp-[build].zip file https://libertyfs.hursley.ibm.com/liberty/dev/Xo/release/[BUILD LABEL]/wlp-[build].zip
WL_ZIP=`curl -u ${AUTH_USERNAME}:${AUTH_PASSWORD} ${LIBERTYFS_BUILD_URL}/ | grep -oE "wlp-${LIBERTY_BUILD_LEVEL}\.zip\"" | sed 's/"//'`
echo "FE_OL_URL=${FE_OL_URL}"
echo "INSTALLABLES_OL_URL=${INSTALLABLES_OL_URL}"
echo "OL_ZIP=${OL_ZIP}"
echo "WL_ZIP=${WL_ZIP}"

##########################

unsetVars
APP_URL="${INSTALLABLES_OL_URL}/${OL_ZIP}"
APP_ARCHIVE="$(basename ${APP_URL})"
EXTRACT_ORIGINAL_NAME=${APP_ARCHIVE}
EXTRACT_NEW_NAME="OL-liberty-${LIBERTY_BUILD_LEVEL}"
APP_DEST="${DEST}/libertyBinaries"
AUTH_NEEDED=true
downloadDepencies

##########################

unsetVars
APP_URL="${LIBERTYFS_BUILD_URL}/${WL_ZIP}"
APP_ARCHIVE="$(basename ${APLIBERTYFS_BUILD_URLP_URL})"
EXTRACT_ORIGINAL_NAME=${APP_ARCHIVE}
EXTRACT_NEW_NAME="WL-liberty-${LIBERTY_BUILD_LEVEL}"
APP_DEST="${DEST}/libertyBinaries"
AUTH_NEEDED=true
downloadDepencies

##########################

