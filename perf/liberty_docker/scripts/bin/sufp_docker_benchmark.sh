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
