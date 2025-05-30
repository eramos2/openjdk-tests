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
#pkill -f "/WPA_INST*"
for jar in ws-launch.jar ws-server.jar; do
    PS_MATCH=`ps aux | grep java | grep ${curr} | grep $jar | grep javaagent | grep -v grep`
    if [ -n "$PS_MATCH" ]; then
	  # Echo processes into build log (stdout)
      echo "$PS_MATCH"
	pids=`ps aux | grep java | grep $PWD | grep $jar | grep javaagent | grep -v grep | awk '{print $2}'`
	for pid_x in $pids
	do
	  kill -9 ${pid_x}
	done
	else
      echo "No previous $jar processes found"
    fi
done
sleep 3

server=$1
if [[ -z $server ]] ; then
	server=server1
	#server=noapp
fi
echo "running server $server"
shift

testHost=`hostname`
testPort=9080
# run request load on same host - note: set frNumaargs for 
#    request load to cpu unused by server startup
requestHost=`hostname`

iters=$1
if [[ -z $iters ]]; then iters=5; fi
echo "running $iters iterations"
shift

DATE=`date "+%y-%m-%d-%k-%M-%S" | tr -d " "`
timeLog=$DATE-time.log
curr=`pwd`
srvrLogDir=${curr}/usr/servers/${server}/logs
echo ${srvrLogDir}
srvrConLog=${srvrLogDir}/console.log
srvrMsgsLog=${srvrLogDir}/messages.log

## NEED TO FIX THIS SO IT CAN BE SET FOR EACH SYSTEM ##
##titans01
#numaargs="numactl --physcpubind 11-12,27-28"
numaargs="numactl --physcpubind ${PHYS_CPU_BIND}"
frNumaargs="numactl --physcpubind ${FR_PHYS_CPU_BIND}"

## NEED TO FIX THIS SO IT CAN BE SET DYNAMICALLY
setMongo="export MONGO_HOST=${MONGO_HOST}"
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

if [[ $server == "acmeair-micro-1.0" ]] || \
    [[ $server == "acmeair-micro-4.0" ]] || \
	[[ $server == "acmeair-mono" ]] || \
	[[ $server == "cdi-base" ]] || \
	[[ $server == "cdi-fat" ]] || \
	[[ $server == "cdi-one-jar-fat" ]] || \
	[[ $server == "pingperf" ]] || \
	[[ $server == "pingperf-jakarta9" ]] || \
	[[ $server == "dt7" ]] || \
	[[ $server == "dt8" ]] || \
	[[ $server == "jaxrs-fat" ]] || \
	[[ $server == "jenkins" ]] || \
	[[ $server == "petclinic" ]] || \
	[[ $server == "spring-1.5.6" ]] || \
	[[ $server == "spring-2.1.1" ]] || \
	[[ $server == "springboot-war" ]] || \
	[[ $server == "tradelite7" ]] || \
	[[ $server == "tradelite8" ]] ; then
	timeToFirstRequest="yes"
fi

#pingperfRequestScript=/sufp/pingperfPingScript.sh
#firstResponseScript=/sufp/pingFirstResponse.sh
firstResponseScript=${TEST_RESROOT}/scripts/sufp/scripts/pingFirstResponse.sh
#cleanupScript=/sufp/cleanupScripts.sh
cleanupScript=${TEST_RESROOT}/scripts/sufp/scripts/cleanupScripts.sh
respMillisFile=/tmp/sufp-resp-millis

echo "*** kill any zombie ping scripts on requestHost ***" 
ssh ${requestHost} "${cleanupScript} ${firstResponseScript}"

startedString=" is ready to run a smarter"

respString=""
testTarget=""

if [[ $server == "pingperf" ]] || [[ $server == "pingperf-jakarta9" ]]; then
	testTarget="/pingperf/ping/greeting"
	respString=" SystemOut "
elif [[ $server == "acmeair-micro-1.0" ]] ; then
	testTarget="/"
#	respString="SRVE0242I.*flightservice.*Initialization successful"
	respString="Complete List : MongoClientOptions"
elif [[ $server == "acmeair-micro-4.0" ]] ; then
	testTarget="/flight"
	respString="SRVE0242I.*acmeair-flightservice.*Initialization successful"
elif [[ $server == "acmeair-micro-5.0" ]] ; then
    testTarget="/auth"
elif [[ $server == "acmeair-mono" ]] ; then
	testTarget="/rest/info/config/runtime"
	respString="SRVE0242I.*acmeair-monolithic.*Initialization successful"
elif [[ $server == "cdi-base" ]] || [[ $server == "cdi-fat" ]] || [[ $server == "cdi-one-jar-fat" ]] ; then
	testTarget="/meetings/rest/meetings"
	respString="SRVE0242I.*meetings.*Initialization successful"
elif [[ $server == "dt7" ]] || [[ $server == "dt8" ]] || [[ $server == "dt9" ]]; then
	testTarget="/daytrader/servlet/PingServlet"
	respString="SRVE0242I.*PingServlet.*Initialization successful"
elif [[ $server == "jaxrs-fat" ]] ; then
	testTarget="/jaxrs-fat/rest/hello/sayHello"
	respString="SRVE0242I.*jaxrs-fat.*Initialization successful"
elif [[ $server == "jenkins" ]] ; then
	testTarget="/jenkins/login"
	respString="SRVE0242I.*jenkins.*Initialization successful"
elif [[ $server == "petclinic" ]] ; then
	testTarget="/petclinic/"
	respString="SRVE0242I.*petclinic.*welcome.jsp.*Initialization successful"
elif [[ $server == "spring-1.5.6" ]] || [[ $server == "spring-2.1.1" ]] ; then
        testTarget="/"
	respString="SRVE0242I.*authservice-springboot.*Initialization successful"
elif [[ $server == "springboot-war" ]] ; then
	testTarget="/spring-petclinic/"
	respString="SRVE0242I.*spring-petclinic.*Initialization successful"
elif [[ $server == "tradelite7" ]] || [[ $server == "tradelite8" ]] ; then
    testTarget="/tradelite/servlet/PingServlet"
	respString="SRVE0242I.*PingServlet.*Initialization successful"
fi

if [[ -z $timeToFirstRequest ]] ; then
	echo -e "\n ****  measuring startup with config  $server  **** \n"
	echo -e "        startedString: '${startedString}' \n"
else
	echo -e "\n ****  measuring first response with app  $server  ****\n"
	echo -e "        first response string: \"$respString\"  "
fi

#pingperfRequestString="while [[ \"$(curl -s -o /dev/null -w ''%{http_code}'' ${testHost}:9080/pingperf/ping/greeting)\" != \"200\" ]]; do sleep 0.001; done"

echo "*** numaargs: $numaargs ***"  | tee -a ${resDir}/${test}.env
echo ""

if [[ ! -z $clearFileCache ]] ; then
	sync;echo 1 > /proc/sys/vm/drop_caches              # clear linux file cache
fi

startCom="${numaargs} ${curr}/bin/server start ${server} "
if [[ ${START_DEBUG} == "true" ]] ; then
	export WLP_DEBUG_SUSPEND=n
	startCom="${numaargs} ${curr}/bin/server debug ${server} "
fi

stopCom="${curr}/bin/server stop ${server}"
timeChk="egrep 'product = |CWWKZ0001I|CWWKF0008I' ${srvrMsgsLog}"

logDir="${resDir}/${test}-logs"
mkdir $logDir

echo " warm up with one un-measured start first "
if [[ ! -z $timeToFirstRequest ]] ; then
#        ( ssh $requestHost $pingperfRequestScript $testHost ) &
		echo "" > $respMillisFile
#		( ssh $requestHost $firstResponseScript $testHost $testPort $testTarget ) &
		( $frNumaargs $firstResponseScript $testHost $testPort $testTarget $respMillisFile ) &
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
#pkill -f "/WPA_INST*"
for jar in ws-launch.jar ws-server.jar; do
    PS_MATCH=`ps aux | grep java | grep ${curr} | grep $jar | grep javaagent | grep -v grep`
    if [ -n "$PS_MATCH" ]; then
	  # Echo processes into build log (stdout)
      echo "$PS_MATCH"
	pids=`ps aux | grep java | grep $PWD | grep $jar | grep javaagent | grep -v grep | awk '{print $2}'`
	for pid_x in $pids
	do
	  kill -9 ${pid_x}
	done
	else
      echo "No previous $jar processes found"
    fi
done
	

if [[ ${TWO_WARMUPS} == "true" ]] ; then
        echo " second warmup start requested"
        if [[ ! -z $timeToFirstRequest ]] ; then
#                ( ssh $requestHost $pingperfRequestScript $testHost ) &
				echo "" > $respMillisFile
				#( ssh $requestHost $firstResponseScript $testHost $testPort $testTarget ) &
				( $frNumaargs $firstResponseScript $testHost $testPort $testTarget $respMillisFile ) &
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
	#pkill -f "/WPA_INST*"
	for jar in ws-launch.jar ws-server.jar; do
    PS_MATCH=`ps aux | grep java | grep ${curr} | grep $jar | grep javaagent | grep -v grep`
    if [ -n "$PS_MATCH" ]; then
	  # Echo processes into build log (stdout)
      echo "$PS_MATCH"
	pids=`ps aux | grep java | grep $PWD | grep $jar | grep javaagent | grep -v grep | awk '{print $2}'`
	for pid_x in $pids
	do
	  kill -9 ${pid_x}
	done
	else
      echo "No previous $jar processes found"
    fi
done
fi

if [[ ${SAVE_ERROR_LOGS} == "true" ]] ; then
        consoleError=`egrep "${ERROR_STRING}" ${srvrLogDir}/console.log`
        messagesError=`egrep "${ERROR_STRING}" ${srvrLogDir}/messages.log`
        if [[ ! -z $consoleError ]] | [[ ! -z $messagesError ]] ; then
                echo "*** errors detected - collecting logs ***"
                zip -j ${logDir}/error-logs-run-${i}.zip ${srvrLogDir}/console.log ${srvrLogDir}/messages.log >/dev/null
        fi
fi

if [[ ${GET_GC_INFO} == "true" ]] ; then
	echo "removing old verbose gc logs"
	rm -f ${srvrLogDir}/verbo*

	echo "Adding verbose gc args to jvm.options"
	if [[ -z ${GC_VALUE} ]]; 
	then
	  GC_VALUE="25,10000"
	fi

	echo "-verbose:gc" > ${srvrLogDir}/../jvm.options
	echo "-Xverbosegclog:${srvrLogDir}/verbosegc.%seq.log,${GC_VALUE}" >> ${srvrLogDir}/../jvm.options
fi

echo " now run the measured iterations "
for i in `seq 1 $iters`; do
        if [[ ${CLEAR_FILE_CACHE} == "true" ]] ; then
                sync;echo 3 > /proc/sys/vm/drop_caches > /dev/null  # clear linux file cache
        fi
	if [[ ${USE_EMPTY_SCC} == "true" ]] ; then
		# clear java class cache
		${JAVA_HOME}/bin/java -Xshareclasses:destroyAll
		libClassCache="${curr}/usr/servers/.classCache"
		echo "dropping Java class cache at ${libClassCache}"
		rm -f ${libClassCache}/*
		sleep 3
	fi
	if [[ ${JAVACORE_DURING_STARTUP} == "true" ]] ; then
		( sleep 0.8
		for x in $(seq 1 ${NUM_JAVACORE_DURING_STARTUP}); do
			kill -3 $(ps -ef | grep java | grep "ws-server.jar ${server}" | grep -v "status:start" | awk '{print $2}')
			sleep 0.5
		done ) &
	fi
        if [[ ! -z $timeToFirstRequest ]] ; then
#                ( ssh $requestHost $pingperfRequestScript $testHost ) &
				 #( ssh $requestHost $firstResponseScript $testHost $testPort $testTarget ) &
				echo "" > $respMillisFile
				( $frNumaargs $firstResponseScript $testHost $testPort $testTarget $respMillisFile ) &
        fi

  	startMillis=`echo $(($(date +%s%N)/1000000))`
	echo "startMillis:" $startMillis   
	${startCom} > /dev/null
	started=""
	while [[ -z $started ]] ; do
		echo "		$(date) - waiting for startup"
		started=$(grep "${startedString}" "${srvrMsgsLog}")
		sleep 3
	done
        stop=`echo $started | sed -e "s/\[//" | sed -e "s/\].*//" | sed 's/\(.*\)\:/\1\./' | tr -d ','`
        let stopMillis=`date "+%s%N" -d "$stop"`/1000000
        let sutime=${stopMillis}-${startMillis}

        resptime=""
        if [[ ! -z $timeToFirstRequest ]] ; then
        	RESP_TIME=""
                while [[ -z $RESP_TIME ]] ; do
#                        resp=`tail -3 ${srvrMsgsLog} | grep " SystemOut " | sed -e "s/.*SystemOut * O //" | awk '{print $1'} | grep -v [a-z,A-Z] | tr -d ','`
                        #resp=$(tail -20 "${srvrMsgsLog}" | grep "$respString" | awk '{print $2}' | sed 's/\(.*\):/\1./')
						#resp=$(cat ${srvrMsgsLog} | grep "$respString" | awk '{print $2}' | sed 's/\(.*\):/\1./')
						RESP_TIME=`grep "[1-9][0-9][0-9]" ${respMillisFile}`
						if [[ ! -z $RESP_TIME ]] ; then
#						        echo " *** resp: $resp *** "
                                #RESP_TIME=`echo $(($(date +%s%N -d $resp)/1000000))`
                                resptime=`expr $RESP_TIME - $startMillis`
                        else
                                sleep 2
                        fi
                done
				echo "RESP_TIME: " $RESP_TIME " resptime: " $resptime
        fi

	if [[ ${NO_SLEEP_FP_CPU} == "false" ]] ; then
		sleep ${SLEEP_FP_CPU}
	fi
#	sleep 15
    server_pid=`ps aux | grep java | grep ws-server.jar | awk '{print $2}'`
	fp0=`ps -e -o pid= -o comm= -o rss= | grep "${server_pid}.*java" | awk '{print $3}'`
	cp0=`top -b -n 1 | grep "${server_pid}.*java" | awk '{print $11}' `
#	acl means "time spent in/under AppClassLoader.loadClass " only works with timing hacked into com.ibm.ws.classloading.jar
#	acl=`grep gjd ${curr}/usr/servers/${server}/logs/console.log | awk '{x+=$6}END{printf "%2.0f ms \n", x/1000000}' `
	if [[ ${EXTRA30} == "true" ]] ; then
		sleep 30	# let post-startup activity (if any) complete and settle down
		server_pid=`ps aux | grep java | grep ws-server.jar | awk '{print $2}'`
		fp1=`ps -e -o pid= -o comm= -o rss= | grep "${server_pid}.*java" | awk '{print $3}'`
		cp1=`top -b -n 1 | grep "${server_pid}.*java" | awk '{print $11}' `
	fi
#echo "***** SLEEPING FOR DIAG *****"
#sleep 5000
	if [[ ${TAKE_JAVACORE} == "true" ]] ; then
		pid=`ps -ef | grep java | grep "ws-server.jar ${server}" | awk '{print $2}'`
		echo "taking javacore on pid $pid with 'kill -3 $pid'"
		kill -3 $pid
		sleep 5
#		targ="${curr}/usr/servers/${server}/javacore.*${pid}.0001.txt"
		targ=`ls -tr ${curr}/usr/servers/${server}/javacore.* | grep $pid | tail -1`
#		egrep "XMTHDCATEGORY.*[1-9]" ${curr}/usr/servers/${server}/javacore.*${pid}.0001.txt  | tee -a ${resFile}
		egrep "XMTHDCATEGORY.*[1-9]" $targ  | tee -a ${resFile}
		if [[ ${GET_JCORE_MEMINFO} == "true" ]] ; then
			grep MEMUSER $targ | egrep "JRE:|VM:|Classes:|Memory Manager|Threads|JIT:|\-Class Librar" | tee -a ${resFile}
		fi
		pid=""
	fi
	if [[ ${GET_GC_INFO} == "true" ]] ; then
		# find the newest GC log
		verboLog=`ls -tr ${srvrLogDir}/ | grep verbose | tail -1`
		gcLog="${srvrLogDir}/${verboLog}"
		if [[ ! -z $gcLog ]] ; then
			tac $gcLog | grep -m 1 -B 10 "gc-end.*glob" | egrep "gc-end|nursery|tenure" | sort  | tee -a ${resFile}
		else
			echo "GET_GC_INFO enabled but no GC log found" | tee -a ${resFile}
		fi
	fi
	if [[ ${GRAB_LOG_TIMES} == "true" ]] ; then
		targ="has been launch|started after|started in|completed in|ready to run"
#		egrep "has been launch|started after|started in|completed in|ready to run" ${curr}/usr/servers/${server}/logs/messages.log  | tee -a ${resFile}
		egrep "${targ}" ${srvrMsgsLog}  | tee -a ${resFile}
	fi
	sleep $sleepTime
	$stopCom > /dev/null
	sleep $sleepTime
	#killall -9 java  2>/dev/null   # ... just in case ...
	#pkill -f "/WPA_INST*"
	for jar in ws-launch.jar ws-server.jar; do
    PS_MATCH=`ps aux | grep java | grep ${curr} | grep $jar | grep javaagent | grep -v grep`
    if [ -n "$PS_MATCH" ]; then
	  # Echo processes into build log (stdout)
      echo "$PS_MATCH"
	pids=`ps aux | grep java | grep $PWD | grep $jar | grep javaagent | grep -v grep | awk '{print $2}'`
	for pid_x in $pids
	do
	  kill -9 ${pid_x}
	done
	else
      echo "No previous $jar processes found"
    fi
    done
	echo -e "$sutime $resptime $fp0 $fp1 \t top: $cp0 $cp1" | tee -a ${resFile}
	if [[ ! -z $timeToFirstRequest ]] ; 
	then
		echo -e "Startup time: $sutime\nFirst Response: $resptime\nFootprint (kb)=$fp0\nCPU: $cp0\napp: $server"
    else
		echo -e "Startup time: $sutime\nFirst Response: n/a\nFootprint (kb)=$fp0\nCPU: $cp0\napp: $server"
    fi
#	echo -e "\t\t AppClassLoader.loadClass time: $acl"  | tee -a ${resFile}
#	egrep 'product = |CWWKZ0001I|CWWKF0008I' ${curr}/usr/servers/${server}/logs/messages.log  > $timeLog
	if [[ ${SAVE_LOGS} == "true" ]] || [[ ${TAKE_JAVACORE} == "true" ]] || [[ ${JAVACORE_DURING_STARTUP} == "true" ]] ; then
		mkdir ${logDir}/run-${i}
		cp ${srvrConLog}  ${logDir}/run-${i}/
		cp ${srvrMsgsLog} ${logDir}/run-${i}/
		cp ${srvrLogDir}/trace.log  ${logDir}/run-${i}/  2>/dev/null
		if [[ ${TAKE_JAVACORE} == "true" ]] || [[ ${JAVACORE_DURING_STARTUP} == "true" ]] ; then
			mv ${curr}/usr/servers/${server}/javacore* ${logDir}/run-${i}/  >/dev/null
		fi
		zip -j ${logDir}/logs-run-${i}.zip ${srvrConLog} ${srvrMsgsLog} >/dev/null
	fi
        if [[ ${SAVE_ERROR_LOGS} == "true" ]] ; then
                consoleError=$(egrep "${ERROR_STRING}" ${srvrLogDir}/console.log)
                messagesError=$(egrep "${ERROR_STRING}" ${srvrLogDir}/messages.log)
                if [[ ! -z $consoleError ]] | [[ ! -z $messagesError ]] ; then
                        echo "*** errors detected - collecting logs ***"
                        zip -j ${logDir}/error-logs-run-${i}.zip ${srvrLogDir}/console.log ${srvrLogDir}/messages.log >/dev/null
                fi
        fi
done 

rm -f $timeLog
echo "" | tee -a ${resFile}

if [[ ${TAKE_JAVACORE} == "true" ]] ; then
	allThrdsAvg=$(awk '/ attached threads/ {x+=$6;y++}END{printf "%2.3f", x/y}' $resFile)
	sysJvmThrdsAvg=$(awk '/System-JVM/ {x+=$3;y++}END{printf "%2.3f", x/y}' $resFile)
	gcThrdsAvg=$(awk '/GC/ {x+=$4;y++}END{printf "%2.3f", x/y}' $resFile)
	jitThrdsAvg=$(awk '/JIT/ {x+=$4;y++}END{printf "%2.3f", x/y}' $resFile)
	applicationThrdsAvg=$(awk '/Application/ {x+=$3;y++}END{printf "%2.3f", x/y}' $resFile)

	sysJvmThrdsPct=$(echo $allThrdsAvg $sysJvmThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}')
	gcJvmThrdsPct=$(echo $allThrdsAvg $gcThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}')
	jitJvmThrdsPct=$(echo $allThrdsAvg $jitThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}')
	applicThrdsPct=$(echo $allThrdsAvg $applicationThrdsAvg | awk '{x+=$1;y+=$2}END{printf "%2.1f", (y*100)/x}')

	echo "***** Javacore Thread CPU usage averages *****" | tee -a ${resFile}
	echo "1XMTHDCATEGORY All JVM attached threads: $allThrdsAvg secs" | tee -a ${resFile}
	echo "2XMTHDCATEGORY +--System-JVM: $sysJvmThrdsAvg secs (${sysJvmThrdsPct}%)" | tee -a ${resFile}
	echo "3XMTHDCATEGORY |  +--GC: $gcThrdsAvg secs (${gcJvmThrdsPct}%)" | tee -a ${resFile}
	echo "3XMTHDCATEGORY |  +--JIT: $jitThrdsAvg secs (${jitJvmThrdsPct}%)" | tee -a ${resFile}
	echo "2XMTHDCATEGORY +--Application: $applicationThrdsAvg secs (${applicThrdsPct}%)" | tee -a ${resFile}
	echo ""  | tee -a ${resFile}
fi
if [[ ${GET_GC_INFO} == "true" ]] ; then
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
if [[ ${GET_JCORE_MEMINFO} == "true" ]] ; then
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

newCalc=""
newCalc="yes"

if [[ -z $newCalc ]] ; then

# ~~~~~~~~~~~ OLD calc ~~~~~~~~~~~~ 
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
if [[ ${EXTRA30} == "true" ]] ; then
	#avg_fp1=`grep top $resFile | awk '{y++;x+=$3} END {print int(x/y+0.5)}'`
	avg_fp1=$(grep top "$resFile" | awk '{x+=$3} END {printf "%.0f", x/NR/1024}')
	avg_cp1=$(grep top "$resFile" | sed -e "s/.* //" | awk -F: '{x+=$1;y+=$2}END{printf "%2.0f:%2.2f", x/NR, y/NR}')
	#echo "${suRes}% ; FP: $avg_fp0 MB, CPU: $avg_cp0 ; After 30 secs- FP: $avg_fp1 MB, CPU: $avg_cp1" | tee -a $resFile
	echo "${suRes}% ; FP: $avg_fp0 MB, CPU: $avg_cp0 ; After 30 secs- FP: $avg_fp1 MB, CPU: $avg_cp1" | tee -a $resFile
else
        if [[ ! -z $timeToFirstRequest ]] ; then
                echo -e "${suRes} \n${respRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
                avg_firstResp=`grep top $resFile | awk '{x+=$2} END {printf "%.0f", x/NR}'`
                #shortRes="SU: $avg_start FR: $avg_firstResp  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
				shortRes="Avg_Startup_time: $avg_start\nAvg_First_Response: $avg_firstResp\nAvg_Footprint_(kb)=$avg_fp0\nAvg_CPU: $avg_cp0\napp: $server"
        else
                echo -e "${suRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
                #shortRes="SU: $avg_start  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
				shortRes="Avg_Startup_time: $avg_start\nAvg_First_Response: n/a\nAvg_Footprint_(kb)=$avg_fp0\nAvg_CPU: $avg_cp0\napp: $server"
        fi
fi
# ~~~~~~~~~~~ OLD calc ~~~~~~~~~~~~ 
else
# ~~~~~~~~~~~ NEW calc ~~~~~~~~~~~~ 
suRes=`awk '/top/ {print $1}' $resFile | sort -n | tail -n+3 | head -n-2 | awk '{sum+=$1; sumsq+=($1)^2; if(min==""){min=max=$1}; if($1>max) {max=$1}; if($1< min) {min=$1}}END{printf "Startup:    Avg: %2.0f ms, Min: %2.0f ms, Max: %2.0f ms, StdDev: %2.0f ms, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
avg_su=`echo $suRes | awk '{print $3}'`
if [[ ! -z $timeToFirstRequest ]] ; then
	respRes=`awk '/top/ {print $2}' $resFile  | sort -n | tail -n+3 | head -n-2 | awk '{rsp=$1; sum+=rsp; sumsq+=(rsp)^2; if(min==""){min=max=rsp}; if(rsp>max) {max=rsp}; if(rsp< min) {min=rsp}}END{printf "Response:   Avg: %2.0f ms, Min: %2.0f ms, Max: %2.0f ms, StdDev: %2.0f ms, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
	avg_fr=`echo $respRes | awk '{print $3}'`
	fpRes=`awk '/top/ {print $3}' $resFile | sort -n | tail -n+3 | head -n-2 | awk '{fp=($1/1024) ; sum+=fp; sumsq+=(fp)^2; if(min==""){min=max=fp}; if(fp>max) {max=fp}; if(fp< min) {min=fp}}END{printf "Footprint:  Avg: %2.0f MB, Min: %2.0f MB, Max: %2.0f MB, StdDev: %2.0f MB, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
else
	fpRes=`awk '/top/ {print $2}' $resFile | sort -n | tail -n+3 | head -n-2 | awk '{fp=($1/1024) ; sum+=fp; sumsq+=(fp)^2; if(min==""){min=max=fp}; if(fp>max) {max=fp}; if(fp< min) {min=fp}}END{printf "Footprint:  Avg: %2.0f MB, Min: %2.0f MB, Max: %2.0f MB, StdDev: %2.0f MB, SDev/Avg: %2.1f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
fi
avg_fp0=`echo $fpRes | awk '{print $3}'` 
cpuRes=`awk -F: '/top/ {printf "%4.2f\n",((60*$2)+$3)}' $resFile | sort -n | tail -n+3 | head -n-2 | awk '{cpu=$1 ; sum+=cpu; sumsq+=(cpu)^2; if(min==""){min=max=cpu}; if(cpu>max) {max=cpu}; if(cpu< min) {min=cpu}}END{printf "CPU usage:  Avg: %2.2f secs, Min: %2.2f secs, Max: %2.2f secs, StdDev: %2.2f secs, SDev/Avg: %2.2f%", sum/NR, min, max, sqrt((sumsq - sum^2/NR)/NR), 100*sqrt((sumsq - sum^2/NR)/NR)/(sum/NR)}'`
avg_cp0=`echo $cpuRes | awk '{print $4}'`
shortRes=""
if [[ ! -z ${EXTRA30} ]] ; then
	#avg_fp1=`grep top $resFile | awk '{y++;x+=$3} END {print int(x/y+0.5)}'`
	avg_fp1=`grep top $resFile | awk '{x+=$3} END {printf "%.0f", x/NR/1024}'`
	avg_cp1=`grep top $resFile | sed -e "s/.* //" | awk -F: '{x+=$1;y+=$2}END{printf "%2.0f:%2.2f", x/NR, y/NR}'`
	echo "${suRes}% ; FP: $avg_fp0 MB, CPU: $avg_cp0 ; After 30 secs- FP: $avg_fp1 MB, CPU: $avg_cp1" | tee -a $resFile
else
	if [[ ! -z $timeToFirstRequest ]] ; then
		echo -e "${suRes} \n${respRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
		#shortRes="SU: $avg_su FR: $avg_fr  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
		shortRes="Avg_Startup_time: $avg_su\nAvg_First_Response: $avg_fr\nAvg_Footprint_(kb)=$avg_fp0\nAvg_CPU: $avg_cp0\napp: $server"
	else
		echo -e "${suRes} \n${fpRes} \n$cpuRes " | tee -a $resFile
		#shortRes="SU: $avg_su FR: n/a  FP: $avg_fp0  CPU: $avg_cp0 app: $server"
		shortRes="Avg_Startup_time: $avg_su\nAvg_First_Response: n/a\nAvg_Footprint_(kb)=$avg_fp0\nAvg_CPU: $avg_cp0\napp: $server"
	fi
fi
# ~~~~~~~~~~~ NEW calc ~~~~~~~~~~~~ 
fi

echo -e $shortRes  | tee -a $resFile

# grab sanity check logs ...
#logDir="${resDir}/${test}-logs"
#mkdir $logDir
zip -j ${logDir}/logs.zip ${srvrMsgsLog} ${srvrConLog} > /dev/null

