#!/usr/bin/env bash

##Expects first paramater to be the liberty build and the second parameter to be the release

DATE=`date "+%y-%m-%d-%k-%M-%S" | tr -d " "`
resultsDir=$3
resDirName=$4
logFile=$5
sufpScriptDir=$6
wpaDir=/WPA_INST
javaDir=/opt/java
javaVersion=java_version.txt
setupServers=${sufpScriptDir}/sufpSetupServers.sh
sufpCycles=${sufpScriptDir}/libertySufpCycles.sh

fullRelease=$2
release=`echo $2 | sed 's/\.//'`
build=`echo $1 | sed 's/.zip//' | grep -o ".\{11\}$"`

targ1=CL-liberty-${1}
targ2=OL-liberty-${1}


unzip -q -o -d $wpaDir/$targ1 $wpaDir/wlp-$1.zip
unzip -q -o -d $wpaDir/$targ2 $wpaDir/openliberty-all-$2-$1.zip


sleep 5
#Remove zip files from dir
rm -rf $wpaDir/wlp-$1.zip openliberty-all-$2-$1.zip

echo "Setting up Servers"

for build in $targ1 $targ2;
do
  cd $wpaDir/${build}/wlp
  $setupServers ${sufpScriptDir}
done

echo "Finished setting up servers"

java=`cat $sufpCycles | grep "export JAVA_HOME" | grep -v "\#setJava" | tail -1 | sed -e 's/\/jre//' | sed -e 's/.*java//' | tr -d '/" ' ` 

echo "java: $java"
#Log java version
$javaDir/$java/bin/java -version

echo "Running Cycles" > $logFile

for build in $targ1 $targ2;
do
  cd $wpaDir/${build}/wlp
  
  for app in `ls usr/servers`;
  do
    echo "Starting test on $app for $build"
    $sufpCycles ${resultsDir} ${build}_${app}_${java}_two-warmups-cpus-4-runs-25-try-1 ${app} 25
    echo "Finished test on $app for $build"
  done
done
echo "Finished Running Cycles"
exit
#Parse results - (Need to enable python3 red hat software collection and virtual environment)
scl enable rh-python36 - << EOF
source /root/pydev/py36-venv/bin/activate
cd /datastore/emmanuel/titans/
python3 get_data.py $fullRelease $resultsDir $resDirName
EOF

sleep 30

echo "Finished parsing results"
date
sleep 5

echo "Finished sufp.sh"
date
#zip -r /datastore/emmanuel/titans/sufp-results_$1_$DATE_archive.zip /opt/IBM/Liberty/sufp-results/*







