#/bin/bash
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

source $(dirname "$0")/test_base_functions.sh

#Set up Java to be used by the elasticsearch-test

if [ -d /java/jre/bin ];then
	echo "Using mounted Java8"
	export JAVA_BIN=/java/jre/bin
	export JAVA_HOME=/java
	export PATH=$JAVA_BIN:$PATH
elif [ -d /java/bin ]; then
	echo "Using mounted Java"
	export JAVA_BIN=/java/bin
	export JAVA_HOME=/java
	export PATH=$JAVA_BIN:$PATH
else
	echo "Using docker image default Java"
	java_path=$(type -p java)
	suffix="/java"
	java_root=${java_path%$suffix}
	export JAVA_BIN="$java_root"
	echo "JAVA_BIN is: $JAVA_BIN"
	export JAVA_HOME="${java_root%/bin}"
fi

TEST_OPTIONS=$1

echo_setup

# Initial command to trigger the execution of elasticsearch test 
cd /elasticsearch

set -e
echo "Building elasticsearch  using gradlew \"gradlew assemble\"" && \
./gradlew -q -g /tmp assemble --exclude-task :distribution:docker:buildDockerImage --exclude-task :distribution:docker:buildOssDockerImage -exclude-task :distribution:docker:docker-export:exportDockerImage -exclude-task :distribution:docker:oss-docker-export:exportOssDockerImage
set +e
echo "Elasticsearch Build - Successful"
echo "================================"
echo ""
echo "Running elasticsearch tests :"

echo $TEST_OPTIONS

./gradlew -q -g /tmp test -Dtests.haltonfailure=false $TEST_OPTIONS
test_exit_code=$?
find ./ -type d -name 'testJunit' -exec cp -r "{}" /testResults \;
exit $test_exit_code
