#!/usr/bin/env bash

#Sample command : /automation/wpa_installs/moss_test/liberty/DevOpsLiberty.sh libertyfs.hursley.ibm.com /liberty/dev/Xo/release/20140911-1301-_587qYDmiEeSW9Y9OBBuvUQ/some.zip _587qYDmiEeSW9Y9OBBuvUQ Moss_Test
#IMPORTATNT: When STAF is restarted, logs /automation/jobs/logs/DevOps_xxx logs should be deleted to properly check the running jobs



cronjobLog=/automation/jobs/logs/RTP_titans01_cronjob.log
echo $(date) "Starting DevOpsLiberty_Titans.sh"

#PERMITTED_SERVER=panthers1.rtp.raleigh.ibm.com
#PERMITTED_SERVER=CHANGEME
#stafServer=$(hostname)

#if [[ $PERMITTED_SERVER != $stafServer ]]
#then
#  echo "Wrong Server.  Please execute this script on "$PERMITTED_SERVER
#  exit 2
#fi


wpa_root=WPA/inst1/root
sufpScriptDir=${1}/scripts/sufp
# Read latest build notification
#latestBuildNotification=`tail -1 /automation/jobs/logs/RTP_titans01_build_notifications.log`
latestBuildNotification="Wed Apr 8 10:30:43 EDT 2020 libfsfe06.hursley.ibm.com /liberty/dev/Xo/release2/cl200520200408-0300-_RzODQHk0EeqVMooXUPL4-g/wlp-tradelite-cl200520200408-0300.zip cl200520200408-0300 20.0.0.5"

repository=`echo $latestBuildNotification | awk '{print $7}'`
tradelite_build_path=`echo $latestBuildNotification | awk '{print $8}'`
build_level=`echo $latestBuildNotification | awk '{print $9}'`
release=`echo $latestBuildNotification | awk '{print $10}'`


# Check build_level and realease have the same label
buildReleaseTag=`echo $build_level | awk '{print substr($1, 3, 4)}'`
releaseLength=`echo $release | awk '{print length}'`
if [[ $releaseLength == 8 ]]
then
  releaseShort=`echo $release | awk '{print substr($1, 1, 2)substr($1, 6, 1)substr($1,8,1)}'`
elif [[ $releaseLength == 9 ]]
then
  releaseShort=`echo $release | awk '{print substr($1, 1, 2)substr($1, 8, 2)}'`
else
  echo "Release label $release has more characters than were expected.  Must be 8 or 9 characters it was $releaseLength, i.e. '20.0.0.4'|'20.0.0.12'. Please try again"
  exit 2
fi

if [[ $releaseShort != $buildReleaseTag ]]
then
  echo "Build label tag and release label tag are not the same. Must be 'cl2004xxxx' and '20.0.0.4'.  Please try again "
  exit 2
fi

url=https://${repository}
build_path=$(echo ${tradelite_build_path%\/*})
stream=$(echo $tradelite_build_path | cut -d/ -f4)
url=https://${repository}${build_path}
common=devops_${stream}.cfg


# Define a timestamp function
timestamp() {
  date +"%c"
}

dirDate=`date "+%y%m%d_%k%M%S" | tr -d " "`
SUT=titans05.rtp.raleigh.ibm.com
load_driver=titans06.rtp.raleigh.ibm.com
scriptDir=${1}/scripts

resDirName=${build_level}_$dirDate
resDir=${1}/libertyResults/$resDirName
logFile=${resDir}/${dirDate}-sufp.log
intranetID=wasperf@us.ibm.com
ePassword="UmVncmVzc2lvbjRQQHRyb2w="
packageTypeCL=default
packageTypeOL=openliberty-all
tempRootDir=/tmp
doDebug=false

#Create resutls Dir
mkdir ${1}/libertyResults
mkdir $resDir
#Get Liberty builds
echo "Downloading CL build"
CL_List=`python $scriptDir/buildDownload.py $stream $intranetID $ePassword $build_level $packageTypeCL $url $tempRootDir $doDebug`
sleep 5
echo "Downloading OL build"
OL_List=`python $scriptDir/buildDownload.py $stream $intranetID $ePassword $build_level $packageTypeOL $url $tempRootDir $doDebug`

#Get the directory where the zip file with the build was downloaded
CL_Tmp_Dir=`echo $CL_List | awk -F\' '{print $6}'`
OL_Tmp_Dir=`echo $OL_List | awk -F\' '{print $6}'`

echo "Transfering zipped builds to SUT"
# Transfer the zipped builds to the SUT WPA_INST directory 
mv $CL_Tmp_Dir/*.zip /WPA_INST/ 
mv $OL_Tmp_Dir/*.zip /WPA_INST/

sleep 5
# Transfer sufp scripts to the SUT
echo "Transfering scripts to SUT"
#scp -r $scriptDir/sufp root@$SUT:/ 
# Transfer pingPerf script to Load driver 
echo "Transfering script to load driver"
#scp -r $scriptDir/sufp/pingperfPingScript.sh root@${load_driver}:/sufp/ 

#Start sufp's scripts
echo "starting scripts"
${sufpScriptDir}/sufp.sh ${build_level} ${release} ${resDir} ${resDirName} ${logFile} ${sufpScriptDir}

echo "Finished sufp.sh, pushing results to database"
date

echo $(date) "Finished scripts "
sleep 5

exit
source /etc/profile
source /root/.bashrc
staf localhost stax execute file /automation/wpa_installs/wpa1/plugins/automation_utils/xml/end2end_utils.xml JOBNAME saveResultsToDatabase FUNCTION end2end_saveResultsToDatabase CLEARLOGS Enabled ARGS [\'${resDir}/\',\'jdbc:db2://wild4.rch.stglabs.ibm.com:50001/scendb\',\'db2inst1\',\'was7perf\',\'Liberty\ ${release}_jdk8\',\'true\'] SCRIPT "pathVar='$wpa_root'"

sleep 210

echo "Zipping results on ${resDir}" >> $cronjobLog
zip /datastore2/results/Liberty_${release}_jdk8/linuxamd64_64/$SUT/sufp-results_${resDirName}_archive.zip ${resDir}/*
#Check staf job to push results finished
pushResultsJob=$(staf localhost stax list jobs | grep -F saveResultsToDatabase)
if [[ $pushResultsJob ]]
then
echo "Job to push results to database is still running couldn't remove results dir" >> ${logFile}
echo "${resDir}" >> ${logFile}
echo "Job to push results to database is still running couldn't remove results dir, please try again later" >> $cronjobLog
echo "${resDir}" >> ${cronjobLog}
else
echo "Removing unzipped results directory" >> $cronjobLog
rm -rf $resDir
fi

echo $(date) Finished >> $cronjobLog

exit


