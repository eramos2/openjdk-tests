#!/usr/bin/env bash

#resDir=/opt/IBM/Liberty/sufp-results
resDir=$1
if [[ -z $resDir ]] ; then echo "must specify results directory" ; exit 99 ; fi
shift
echo "this is the $resDir"
test=$1
if [[ -z $test ]] ; then echo "must specify test name" ; exit 99 ; fi
if [[ ! -z `ls ${resDir}/${test}.env 2>/dev/null ` ]] ; then echo "test results env already exists - aborting to avoid overwriting"; exit 99; fi
if [[ ! -z `ls ${resDir}/${test}.sufp.results 2>/dev/null ` ]] ; then echo "test results already exist - aborting to avoid overwriting"; exit 99; fi
shift

echo "***killing all java procs ***"
#killall -9 java
pkill -f "/WPA_INST*"
sleep 3

server=$1
if [[ -z $server ]] ; then
	server=server1
	#server=noapp
fi
echo "running server $server"
shift

testHost=`hostname`
requestHost=titans06.rtp.raleigh.ibm.com

iters=$1
if [[ -z $iters ]]; then iters=5; fi
echo "running $iters iterations"

DATE=`date "+%y-%m-%d-%k-%M-%S" | tr -d " "`
timeLog=$DATE-time.log
curr=`pwd`
srvrLogDir=${curr}/usr/servers/${server}/logs
srvrConLog=${srvrLogDir}/console.log
srvrMsgsLog=${srvrLogDir}/messages.log

# choose java version
setJava="export JAVA_HOME=/opt/java/hs-8u201/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828sr3-GA/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828sr3-fp20/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr4-fp5/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp7/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp10/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp11/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp15/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp16/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp17/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp22/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp25/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp27/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp30/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp35/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp37/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp40/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr5-fp41/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr6-fp0/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr6-fp5/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr6-fp6ifix/jre "
setJava="export JAVA_HOME=/opt/java/j9-828-sr6-fp7/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr6-180417_01/jre "
#setJava="export JAVA_HOME=/opt/java/j9-828-sr6-191107/jre "
#setJava="export JAVA_HOME=/opt/java/irwin-sr6-with-7703/jre "
#setJava="export JAVA_HOME=/opt/java/irwin-sr6-without-7703/jre "
#setJava="export JAVA_HOME=/opt/java/pxa6480sr6-20191107_01_changeRemoved/jre "
#setJava="export JAVA_HOME=/opt/java/pxa6480sr6-20191107_01_baseline/jre "
#setJava="export JAVA_HOME=/opt/java/pxa6480sr6-20191107_01_untouched/jre "
#setJava="export JAVA_HOME=/opt/java/j9-929-170327_02/jre "
#setJava="export JAVA_HOME=/opt/java/openj9-8u202b08/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u212b03/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u222b10/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b09/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u242b08/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b00-190821/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b00-190821-vijay/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b03-190906-vijay/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u222b10-190816/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b03-190827/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b03-190829/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-11.0.5_4/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-11-200127-140131/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-11-200213-111925/jre"
#setJava="export JAVA_HOME=/opt/java/j9-11-class-verify-part-2-v2/jre"
#setJava="export JAVA_HOME=/opt/java/openhs-8u212b03/jre"
#setJava="export JAVA_HOME=/opt/java/openhs-8u222b10/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b03-190906-vijay/jre"
#setJava="export JAVA_HOME=/opt/java/openj9-8u232b05-190917/jre"
#setJava="export JAVA_HOME=/opt/java/openhs-8u232b05-190917/jre"
#$setJava

#numaargs="numactl -N 0"
#numaargs="numactl --physcpubind 2"
#numaargs="numactl --physcpubind 14"
#numaargs="numactl --physcpubind 14-17"
#numaargs="numactl --physcpubind 12-17"
#numaargs="numactl --physcpubind 2-5"
#numaargs="numactl --physcpubind 2,10"
#numaargs="numactl --physcpubind 2-3,30-31"
#numaargs="numactl --physcpubind 14-27"
#numaargs="numactl --physcpubind 7-13"
#numaargs="numactl --physcpubind 0-27"
#numaargs="numactl --physcpubind 14-27,42-55"
##titans01
numaargs="numactl --physcpubind 11-12,27-28"

#numaargs=""

#setMalloc="export MALLOC_ARENA_MAX=1"
#$setMalloc

setMongo="export MONGO_HOST=titans08"
$setMongo

ibmJava=`echo $JAVA_HOME | grep j9`
if [[ ! -z $ibmJava  ]] ; then echo "using IBM Java"
	# clear java class cache
	${JAVA_HOME}/bin/java -Xshareclasses:destroyAll
	libClassCache="${curr}/usr/servers/.classCache"
	echo "dropping Java class cache at ${libClassCache}"
	rm -f ${libClassCache}/*
	sleep 3
fi

# clear tranlog and workarea ... tidying up in case switching java8/9 levels
rm -rf ${curr}/usr/servers/${server}/tranlog ${curr}/usr/servers/${server}/workarea/

resFile=${resDir}/${test}.sufp.results

echo "=======================================" | tee -a ${resDir}/${test}.env
echo "Liberty version" | tee -a ${resDir}/${test}.env 
echo "=======================================" | tee -a ${resDir}/${test}.env
${curr}/bin/server version | tee -a ${resDir}/${test}.env
echo "=======================================" | tee -a ${resDir}/${test}.env
echo "Java version" | tee -a ${resDir}/${test}.env
echo "=======================================" | tee -a ${resDir}/${test}.env
echo "JAVA_HOME: $JAVA_HOME" | tee -a ${resDir}/${test}.env
${JAVA_HOME}/bin/java -version | tee -a ${resDir}/${test}.env
echo "=======================================" | tee -a ${resDir}/${test}.env
echo "server.xml" | tee -a ${resDir}/${test}.env 
echo "=======================================" | tee -a ${resDir}/${test}.env
cat ${curr}/usr/servers/${server}/server.xml  | tee -a ${resDir}/${test}.env
echo "=======================================" | tee -a ${resDir}/${test}.env
# jvm.options file may be in the server dir, if not it may be in etc
jvmOpts=""
filechk=`ls ${curr}/usr/servers/${server}/jvm.options 2> /dev/null`
if [[ ! -z $filechk ]] ; then
        jvmOpts="${curr}/usr/servers/${server}/jvm.options"
else
        filechk2=`ls ${curr}/etc/jvm.options 2> /dev/null`
        #echo "filechk2: $filechk2"
        if [[ ! -z $filechk2 ]] ; then
                jvmOpts=${curr}/etc/jvm.options
        fi
fi
if [[ -z $jvmOpts ]] ; then
        echo "jvm.options file not found in server or etc dirs " | tee -a ${resDir}/${test}.env
else
	echo "jvm.options" | tee -a ${resDir}/${test}.env 
	echo "=======================================" | tee -a ${resDir}/${test}.env
	cat ${jvmOpts} | tee -a ${resDir}/${test}.env
fi
echo ""
bootProps=""
bootProps=`ls ${curr}/usr/servers/${server}/bootstrap.properties 2> /dev/null`
if [[ -z $bootProps ]] ; then
        echo "bootstrap.properties file not found in server dir" | tee -a ${resDir}/${test}.env
else
        echo "=======================================" | tee -a ${resDir}/${test}.env
        echo "bootstrap.properties"  | tee -a ${resDir}/${test}.env
        echo "=======================================" | tee -a ${resDir}/${test}.env
        cat ${bootProps} |  tee -a ${resDir}/${test}.env
fi
echo ""

patchedJars=""
patchedJars=`ls lib/*orig |  sed -e "s/\.jar.*/\.jar\*/"`
if [[ -z $patchedJars ]] ; then
        echo "no patched jars found in lib dir" | tee -a ${resDir}/${test}.env
else
        echo "++++++++++++++++++++++++++++++" | tee -a ${resDir}/${test}.env
        echo "patched jars found in lib dir" | tee -a ${resDir}/${test}.env
        echo "++++++++++++++++++++++++++++++" | tee -a ${resDir}/${test}.env
        ls -l $patchedJars | tee -a ${resDir}/${test}.env
fi
echo ""  | tee -a ${resDir}/${test}.env

echo "check for gjd tweaks in Liberty bin dir" | tee -a ${resDir}/${test}.env
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${resDir}/${test}.env
grep gjd bin/* 2>/dev/null | tee -a ${resDir}/${test}.env
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" | tee -a ${resDir}/${test}.env

sleepTime=5
timeToFirstRequest=""

if [[ $server == "pingperf" ]] ; then
	timeToFirstRequest="yes"
fi

if [[ -z $timeToFirstRequest ]] ; then
	echo -e "\n ****  measuring startup with app  $server  **** \n"
else
	echo -e "\n ****  measuring first response with app  $server  ****\n"
fi

#pingperfRequestString="while [[ \"$(curl -s -o /dev/null -w ''%{http_code}'' ${testHost}:9080/pingperf/ping/greeting)\" != \"200\" ]]; do sleep 0.001; done"

pingperfRequestScript=/sufp/pingperfPingScript.sh

extra30=""
noSleepFPCPU=""
#noSleepFPCPU="yes"
javacoreDuringStartup=""
#javacoreDuringStartup="yes"
numJavacoreDuringStartup=15
numJavacoreDuringStartup=1
takeJavacore=""
#takeJavacore="yes"
getJcoreMemInfo=""
#getJcoreMemInfo="yes"
getGCInfo=""
#getGCInfo="yes"
grabLogTimes=""
#grabLogTimes="yes"
useEmptySCC=""
#useEmptySCC="yes"
saveLogs=""
#saveLogs="yes"
saveErrorLogs=""
#saveErrorLogs="yes"
errorString="Exception |FFDC1015I|CWWKF0042E"

twoWarmups=""
twoWarmups="yes"
clearFileCache=""
clearFileCache="yes"
startDebug=""
#startDebug="yes"

echo "*** numaargs: $numaargs ***"  | tee -a ${resDir}/${test}.env
echo ""

startedString=" is ready to run a smarter"
app=""
#app="jenkins"
if [[ "$server" == "jenkins" ]] ; then
        startedString="Jenkins is fully up and running"
fi
echo -e "startedString: '${startedString}' \n"


startCom="${numaargs} ${curr}/bin/server start ${server} "
if [[ ! -z $startDebug ]] ; then
	export WLP_DEBUG_SUSPEND=n
	startCom="${numaargs} ${curr}/bin/server debug ${server} "
fi

stopCom="${curr}/bin/server stop ${server}"
timeChk="egrep 'product = |CWWKZ0001I|CWWKF0008I' ${srvrMsgsLog}"

logDir="${resDir}/${test}-logs"
mkdir $logDir

echo " warm up with one un-measured start first "
if [[ ! -z $timeToFirstRequest ]] ; then
        ( ssh $requestHost $pingperfRequestScript $testHost ) &
fi
${startCom} --clean > /dev/null
started=""
while [[ -z $started ]] ; do
        echo "		`date` - waiting for startup"
        started=`grep "${startedString}" ${srvrMsgsLog}`
        sleep 5
done
$stopCom > /dev/null
sleep 15
#killall -9 java   # ... just in case ...
pkill -f "/WPA_INST*"

if [[ ! -z $twoWarmups ]] ; then
        echo " second warmup start requested"
        if [[ ! -z $timeToFirstRequest ]] ; then
                ( ssh $requestHost $pingperfRequestScript $testHost ) &
        fi
        ${startCom} > /dev/null
	started=""
	while [[ -z $started ]] ; do
		echo "		`date` - waiting for startup"
		started=`grep "${startedString}" ${srvrMsgsLog}`
		sleep 5
	done
        $stopCom > /dev/null
        sleep 15
	#killall -9 java   # ... just in case ...
	pkill -f "/WPA_INST*"
fi

if [[ ! -z $saveErrorLogs ]] ; then
        consoleError=`egrep "${errorString}" ${srvrLogDir}/console.log`
        messagesError=`egrep "${errorString}" ${srvrLogDir}/messages.log`
        if [[ ! -z $consoleError ]] | [[ ! -z $messagesError ]] ; then
                echo "*** errors detected - collecting logs ***"
                zip -j ${logDir}/error-logs-run-${i}.zip ${srvrLogDir}/console.log ${srvrLogDir}/messages.log >/dev/null
        fi
fi

if [[ ! -z $getGCInfo ]] ; then
	echo "removing old verbose gc logs"
	rm -f ${srvrLogDir}/verbo*
fi

echo " now run the measured iterations "
for i in `seq 1 $iters`; do
        if [[ ! -z $clearFileCache ]] ; then
                sync;echo 3 > /proc/sys/vm/drop_caches > /dev/null  # clear linux file cache
        fi
	if [[ ! -z $useEmptySCC ]] ; then
		# clear java class cache
		${JAVA_HOME}/bin/java -Xshareclasses:destroyAll
		libClassCache="${curr}/usr/servers/.classCache"
		echo "dropping Java class cache at ${libClassCache}"
		rm -f ${libClassCache}/*
		sleep 3
	fi
	if [[ ! -z $javacoreDuringStartup ]] ; then
		( sleep 0.8
		for x in `seq 1 ${numJavacoreDuringStartup}`; do
			kill -3 `ps -ef | grep java | grep "ws-server.jar ${server}" | grep -v "status:start" | awk '{print $2}'`
			sleep 0.5
		done ) &
	fi
        if [[ ! -z $timeToFirstRequest ]] ; then
                ( ssh $requestHost $pingperfRequestScript $testHost ) &
        fi

  	startMillis=`echo $(($(date +%s%N)/1000000))`
	${startCom} > /dev/null
	started=""
	while [[ -z $started ]] ; do
		echo "		`date` - waiting for startup"
		started=`grep "${startedString}" ${srvrMsgsLog}`
		sleep 3
	done
        stop=`echo $started | sed -e "s/\[//" | sed -e "s/\].*//" | sed 's/\(.*\)\:/\1\./' | tr -d ','`
        let stopMillis=`date "+%s%N" -d "$stop"`/1000000
        let sutime=${stopMillis}-${startMillis}

        resptime=""
        if [[ ! -z $timeToFirstRequest ]] ; then
        	RESP_TIME=""
                while [[ -z $RESP_TIME ]] ; do
                        resp=`tail -3 ${srvrMsgsLog} | grep " SystemOut " | sed -e "s/.*SystemOut * O //" | awk '{print $1'} | grep -v [a-z,A-Z] | tr -d ','`
                        if [[ ! -z $resp ]] ; then
                                RESP_TIME=`echo $(($(date +%s%N -d $resp)/1000000))`
                                resptime=`expr $RESP_TIME - $startMillis`
                        else
                                sleep 2
                        fi
                done
        fi

	if [[ -z $noSleepFPCPU ]] ; then
		sleep 15
	fi
#	sleep 15
    libPid=`ps -ef | grep java | grep liberty | awk '{print $2}'`
	fp0=`ps -q $libPid -o pid= -o comm= -o rss= | awk '{print $3}'`
	cp0=`top -b -n 1 | grep java | awk '{print $11}' `
#	acl means "time spent in/under AppClassLoader.loadClass " only works with timing hacked into com.ibm.ws.classloading.jar
#	acl=`grep gjd ${curr}/usr/servers/${server}/logs/console.log | awk '{x+=$6}END{printf "%2.0f ms \n", x/1000000}' `
	if [[ ! -z $extra30 ]] ; then
		sleep 30	# let post-startup activity (if any) complete and settle down
		fp1=`ps -q $libPid -o pid= -o comm= -o rss= | awk '{print $3}'`
		libPid=`ps -ef | grep java | grep liberty | awk '{print $2}'`
		cp1=`top -b -n 1 | grep java | awk '{print $11}' `
	fi
#echo "***** SLEEPING FOR DIAG *****"
#sleep 5000
	if [[ ! -z $takeJavacore ]] ; then
		pid=`ps -ef | grep java | grep "ws-server.jar ${server}" | awk '{print $2}'`
		echo "taking javacore on pid $pid with 'kill -3 $pid'"
		kill -3 $pid
		sleep 5
#		targ="${curr}/usr/servers/${server}/javacore.*${pid}.0001.txt"
		targ=`ls -tr ${curr}/usr/servers/${server}/javacore.* | grep $pid | tail -1`
#		egrep "XMTHDCATEGORY.*[1-9]" ${curr}/usr/servers/${server}/javacore.*${pid}.0001.txt  | tee -a ${resFile}
		egrep "XMTHDCATEGORY.*[1-9]" $targ  | tee -a ${resFile}
		if [[ ! -z $getJcoreMemInfo ]] ; then
			grep MEMUSER $targ | egrep "JRE:|VM:|Classes:|Memory Manager|Threads|JIT:|\-Class Librar" | tee -a ${resFile}
		fi
		pid=""
	fi
	if [[ ! -z $getGCInfo ]] ; then
		# find the newest GC log
		verboLog=`ls -tr ${srvrLogDir}/ | grep verbose | tail -1`
		gcLog="${srvrLogDir}/${verboLog}"
		if [[ ! -z $gcLog ]] ; then
			tac $gcLog | grep -m 1 -B 10 "gc-end.*glob" | egrep "gc-end|nursery|tenure" | sort  | tee -a ${resFile}
		else
			echo "getGCInfo enabled but no GC log found" | tee -a ${resFile}
		fi
	fi
	if [[ ! -z $grabLogTimes ]] ; then
		targ="has been launch|started after|started in|completed in|ready to run"
#		egrep "has been launch|started after|started in|completed in|ready to run" ${curr}/usr/servers/${server}/logs/messages.log  | tee -a ${resFile}
		egrep "${targ}" ${srvrMsgsLog}  | tee -a ${resFile}
	fi
	sleep $sleepTime
	$stopCom > /dev/null
	sleep $sleepTime
	#killall -9 java  2>/dev/null   # ... just in case ...
	pkill -f "/WPA_INST*"
	echo -e "$sutime $resptime $fp0 $fp1 \t top: $cp0 $cp1" | tee -a ${resFile}
#	echo -e "\t\t AppClassLoader.loadClass time: $acl"  | tee -a ${resFile}
#	egrep 'product = |CWWKZ0001I|CWWKF0008I' ${curr}/usr/servers/${server}/logs/messages.log  > $timeLog
	if [[ ! -z $saveLogs ]] || [[ ! -z $takeJavacore ]] || [[ ! -z $javacoreDuringStartup ]] ; then
		mkdir ${logDir}/run-${i}
		cp ${srvrConLog}  ${logDir}/run-${i}/
		cp ${srvrMsgsLog} ${logDir}/run-${i}/
		cp ${srvrLogDir}/trace.log  ${logDir}/run-${i}/  2>/dev/null
		if [[ ! -z $takeJavacore ]] || [[ ! -z $javacoreDuringStartup ]] ; then
			mv ${curr}/usr/servers/${server}/javacore* ${logDir}/run-${i}/  >/dev/null
		fi
		zip -j ${logDir}/logs-run-${i}.zip ${srvrConLog} ${srvrMsgsLog} >/dev/null
	fi
        if [[ ! -z $saveErrorLogs ]] ; then
                consoleError=`egrep "${errorString}" ${srvrLogDir}/console.log`
                messagesError=`egrep "${errorString}" ${srvrLogDir}/messages.log`
                if [[ ! -z $consoleError ]] | [[ ! -z $messagesError ]] ; then
                        echo "*** errors detected - collecting logs ***"
                        zip -j ${logDir}/error-logs-run-${i}.zip ${srvrLogDir}/console.log ${srvrLogDir}/messages.log >/dev/null
                fi
        fi
done 

rm -f $timeLog
echo "" | tee -a ${resFile}

if [[ ! -z $takeJavacore ]] ; then
	allThrdsAvg=`awk '/ attached threads/ {x+=$6;y++}END{printf "%2.3f", x/y}' $resFile`
	sysJvmThrdsAvg=`awk '/System-JVM/ {x+=$3;y++}END{printf "%2.3f", x/y}' $resFile`
	gcThrdsAvg=`awk '/GC/ {x+=$4;y++}END{printf "%2.3f", x/y}' $resFile`
	jitThrdsAvg=`awk '/JIT/ {x+=$4;y++}END{printf "%2.3f", x/y}' $resFile`
	applicationThrdsAvg=`awk '/Application/ {x+=$3;y++}END{printf "%2.3f", x/y}' $resFile`

	sysJvmThrdsPct=`echo $allThrdsAvg $sysJvmThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}'`
	gcJvmThrdsPct=`echo $allThrdsAvg $gcThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}'`
	jitJvmThrdsPct=`echo $allThrdsAvg $jitThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}'`
	applicThrdsPct=`echo $allThrdsAvg $applicationThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}'`

	echo "***** Javacore Thread CPU usage averages *****" | tee -a ${resFile}
	echo "1XMTHDCATEGORY All JVM attached threads: $allThrdsAvg secs" | tee -a ${resFile}
	echo "2XMTHDCATEGORY +--System-JVM: $sysJvmThrdsAvg secs (${sysJvmThrdsPct}%)" | tee -a ${resFile}
	echo "3XMTHDCATEGORY |  +--GC: $gcThrdsAvg secs (${gcJvmThrdsPct}%)" | tee -a ${resFile}
	echo "3XMTHDCATEGORY |  +--JIT: $jitThrdsAvg secs (${jitJvmThrdsPct}%)" | tee -a ${resFile}
	echo "2XMTHDCATEGORY +--Application: $applicationThrdsAvg secs (${applicThrdsPct}%)" | tee -a ${resFile}
	echo ""  | tee -a ${resFile}
fi
if [[ ! -z $getGCInfo ]] ; then
        avgNurserySize=`grep "mem type=\"nursery" ${resFile} | awk -F\" '{x+=$6}END{printf "%2.2f",  x/NR/1024/1024}'`
        avgNurseryUsed=`grep "mem type=\"nursery" ${resFile} | awk -F\" '{x+=$6;x-=$4}END{printf "%2.2f",  x/NR/1024/1024}'`
        avgTenureSize=`grep "mem type=\"tenure" ${resFile} | awk -F\" '{x+=$6}END{printf "%2.2f",  x/NR/1024/1024}'`
        avgTenureUsed=`grep "mem type=\"tenure" ${resFile} | awk -F\" '{x+=$6;x-=$4}END{printf "%2.2f",  x/NR/1024/1024}'`
        avgTotalSize=`egrep "mem type=\"nursery|mem type=\"tenure" ${resFile} | awk -F\" '{x+=$6}END{printf "%2.2f",  x/(NR/2)/1024/1024}'`
        avgTotalUsed=`egrep "mem type=\"nursery|mem type=\"tenure" ${resFile} | awk -F\" '{x+=$6;x-=$4}END{printf "%2.2f",  x/(NR/2)/1024/1024}'`

	echo "***** GC log heap size/usage averages *****" | tee -a ${resFile}
	echo "Average nursery heap size: $avgNurserySize MB" | tee -a ${resFile}
	echo "Average nursery heap used: $avgNurseryUsed MB" | tee -a ${resFile}
	echo "Average tenure heap size:  $avgTenureSize MB" | tee -a ${resFile}
	echo "Average tenure heap used:  $avgTenureUsed MB" | tee -a ${resFile}
        echo "Average total heap size:  $avgTotalSize MB" | tee -a ${resFile}
        echo "Average total heap used:  $avgTotalUsed MB" | tee -a ${resFile}
	echo ""  | tee -a ${resFile}

	zip -qj ${resDir}/${test}.gc-logs.zip  ${srvrLogDir}/verbo*
fi
if [[ ! -z $getJcoreMemInfo ]] ; then
	avgJREmem=`grep "MEMUSER.*JRE" ${resFile} | tr -d "," | awk '{x+=$3}END{printf "%2.2f", x/NR/1024/1024}'`
	avgVMmem=`grep "MEMUSER.*VM" ${resFile} | tr -d "," | awk '{x+=$3}END{printf "%2.2f", x/NR/1024/1024}'`
	avgClassesmem=`grep "MEMUSER.*Classes" ${resFile} | tr -d "," | awk '{x+=$4}END{printf "%2.2f", x/NR/1024/1024}'`
	avgHeapmem=`grep "MEMUSER.*Memory Manag" ${resFile} | tr -d "," | awk '{x+=$6}END{printf "%2.2f", x/NR/1024/1024}'`
	avgThreadsmem=`grep "MEMUSER.*Threads" ${resFile} | tr -d "," | awk '{x+=$4}END{printf "%2.2f", x/NR/1024/1024}'`
	avgJITmem=`grep "MEMUSER.*JIT" ${resFile} | tr -d "," | awk '{x+=$3}END{printf "%2.2f", x/NR/1024/1024}'`
	avgClassLibmem=`grep "MEMUSER.*Class Librar" ${resFile} | tr -d "," | awk '{x+=$4}END{printf "%2.2f", x/NR/1024/1024}'`

	echo "***** Javacore Memory Size averages *****" | tee -a ${resFile}
	echo "Average total JRE size: $avgJREmem MB" | tee -a ${resFile}
	echo "Average total VM size: $avgVMmem MB" | tee -a ${resFile}
	echo "Average total Classes size: $avgClassesmem MB" | tee -a ${resFile}
	echo "Average total Heap size: $avgHeapmem MB" | tee -a ${resFile}
	echo "Average total Threads size: $avgThreadsmem MB" | tee -a ${resFile}
	echo "Average total JIT size: $avgJITmem MB" | tee -a ${resFile}
	echo "Average total Class Libraries size: $avgClassLibmem MB" | tee -a ${resFile}

	echo ""  | tee -a ${resFile}
fi
suRes=`grep top $resFile | awk '{sum+=$1; sumsq+=($1)^2; if(min==""){min=max=$1}; if($1>max) {max=$1}; if($1< min) {min=$1}}END{printf "Startup:    Avg: %2.0f ms, Min: %2.0f ms, Max: %2.0f ms, StdDev: %2.0f ms, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
if [[ ! -z $timeToFirstRequest ]] ; then
        respRes=`grep top $resFile | awk '{rsp=$2; sum+=rsp; sumsq+=(rsp)^2; if(min==""){min=max=rsp}; if(rsp>max) {max=rsp}; if(rsp< min) {min=rsp}}END{printf "Response:   Avg: %2.0f ms, Min: %2.0f ms, Max: %2.0f ms, StdDev: %2.0f ms, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
        fpRes=`grep top $resFile | awk '{fp=($3/1024) ; sum+=fp; sumsq+=(fp)^2; if(min==""){min=max=fp}; if(fp>max) {max=fp}; if(fp< min) {min=fp}}END{printf "Footprint:  Avg: %2.0f MB, Min: %2.0f MB, Max: %2.0f MB, StdDev: %2.0f MB, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
	#avg_fp0=`grep top $resFile | awk '{x+=$3} END {printf "%.0f", x/NR/1024}'`
	avg_fp0=`grep top $resFile | awk '{x+=$3} END {printf "%.0f", x/NR}'`
else
	fpRes=`grep top $resFile | awk '{fp=($2/1024) ; sum+=fp; sumsq+=(fp)^2; if(min==""){min=max=fp}; if(fp>max) {max=fp}; if(fp< min) {min=fp}}END{printf "Footprint:  Avg: %2.0f MB, Min: %2.0f MB, Max: %2.0f MB, StdDev: %2.0f MB, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
	#avg_fp0=`grep top $resFile | awk '{x+=$2} END {printf "%.0f", x/NR/1024}'`
	avg_fp0=`grep top $resFile | awk '{x+=$2} END {printf "%.0f", x/NR}'`
fi
cpuRes=`grep top $resFile | awk -F: '{cpu=((60*$2)+$3) ; sum+=cpu; sumsq+=(cpu)^2; if(min==""){min=max=cpu}; if(cpu>max) {max=cpu}; if(cpu< min) {min=cpu}}END{printf "CPU usage:  Avg: %2.2f secs, Min: %2.2f secs, Max: %2.2f secs, StdDev: %2.2f secs, SDev/Avg: %2.2f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
avg_cp0=`grep top $resFile | awk -F: '{x+=$2;y+=$3}END{printf "%2.2f", 60*x/NR + y/NR}'` 
shortRes=""
avg_start=`grep top $resFile | awk '{x+=$1} END {printf "%.0f", x/NR}'`
if [[ ! -z $extra30 ]] ; then
	#avg_fp1=`grep top $resFile | awk '{y++;x+=$3} END {print int(x/y+0.5)}'`
	avg_fp1=`grep top $resFile | awk '{x+=$3} END {printf "%.0f", x/NR/1024}'`
	avg_cp1=`grep top $resFile | sed -e "s/.* //" | awk -F: '{x+=$1;y+=$2}END{printf "%2.0f:%2.2f", x/NR, y/NR}'`
	#echo "${suRes}% ; FP: $avg_fp0 MB, CPU: $avg_cp0 ; After 30 secs- FP: $avg_fp1 MB, CPU: $avg_cp1" | tee -a $resFile
	echo "${suRes}% ; FP: $avg_fp0 MB, CPU: $avg_cp0 ; After 30 secs- FP: $avg_fp1 MB, CPU: $avg_cp1" | tee -a $resFile
else
        if [[ ! -z $timeToFirstRequest ]] ; then
                echo -e "${suRes} \n${respRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
                avg_firstResp=`grep top $resFile | awk '{x+=$2} END {printf "%.0f", x/NR}'`
                #shortRes="SU: $avg_start FR: $avg_firstResp  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
				shortRes="Startup time: $avg_start\nFR: $avg_firstResp\nFootprint (kb)=$avg_fp0\nCPU: $avg_cp0\napp: $server"
        else
                echo -e "${suRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
                #shortRes="SU: $avg_start  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
				shortRes="Startup time: $avg_start\nFootprint (kb)=$avg_fp0\nCPU: $avg_cp0\napp: $server"
        fi
fi

echo -e $shortRes  | tee -a $resFile

# grab sanity check logs ...
#logDir="${resDir}/${test}-logs"
#mkdir $logDir
zip -j ${logDir}/logs.zip ${srvrMsgsLog} ${srvrConLog} > /dev/null

