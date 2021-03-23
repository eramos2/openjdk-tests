#!/usr/bin/env bash

##Expects first paramater to be the liberty build and the second parameter to be the release
DATE=`date "+%y-%m-%d-%k-%M-%S" | tr -d " "`
resultsDir=$3
resDirName=$4
logFile=$5
sufpScriptDir=$6
wpaDir=${LIBERTY_BINARIES_DIR}/
javaDir=/opt/java
javaVersion=java_version.txt
setupServers=${sufpScriptDir}/sufpSetupServers.sh
sufpCycles=${sufpScriptDir}/libertySufpCycles.sh
runs=${MEASUREMENT_RUNS}
libertyVersion=${LIBERTY_VERSION}
fullRelease=$2
release=`echo $2 | sed 's/\.//'`
build=`echo $1 | sed 's/.zip//' | grep -o ".\{11\}$"`

if [[ ${libertyVersion} == "CL" ]]
then
  targ1=CL-liberty-${1}
  unzip -q -o -d $wpaDir/$targ1 $wpaDir/wlp-$1.zip
  sleep 5
  rm -rf $wpaDir/wlp-$1.zip
else
  targ1=OL-liberty-${1}
  unzip -q -o -d $wpaDir/$targ1 $wpaDir/openliberty-all-$2-$1.zip
  sleep 5
  rm -rf $wpaDir/openliberty-all-$2-$1.zip
fi 

# echo "Setting up Servers"

# #for build in $targ1 $targ2;
# for build in ${targ1};
# do
#   cd $wpaDir/${build}/wlp
#   $setupServers ${sufpScriptDir}
# done

# echo "Finished setting up servers"

java=`cat $sufpCycles | grep "export JAVA_HOME" | grep -v "\#setJava" | tail -1 | sed -e 's/\/jre//' | sed -e 's/.*java//' | tr -d '/" ' ` 

echo "java: $java"
#Log java version
$javaDir/$java/bin/java -version

echo "Running Cycles" > $logFile

#for build in $targ1 $targ2;
for build in ${targ1};
do
  cd $wpaDir/${build}/wlp
  echo $apps
  for app in `echo $apps`;
  do
    echo "Starting test on $app for $build"
    $sufpCycles ${resultsDir} ${build}_${app}_${java}_two-warmups-cpus-4-runs-${runs}-try-1 ${app} ${runs}
    echo "Finished test on $app for $build"
  done
done
echo "Finished Running Cycles"

## TODO Add an variable to check if builds need to be removed from SUT
echo "Removing Builds $targ1"
rm -rf $targ1

exit
