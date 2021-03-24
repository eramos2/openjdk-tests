#!/usr/bin/env bash
# Array of all the apps to setup/run
#apps=(acmeair-micro acmeair-mono cdi-base cdi-fat cdi-one-jar-fat dt7 dt8 huge-ejb javaee7 javaee8 jaxrs-fat jenkins micro-profile-3 no-app no-feat petclinic pingperf spring-1.5.6 spring-2.1.1 tradelite7 tradelite8 webProfile7 webProfile8)
#apps=(dt7)
echo "${APP}"
sufpScriptDir=$1

echo "about to kill all java procs, unless you stop me in next 10 secs"
sleep 15
#killall -9 java
#pkill -f "/WPA_INST*"
for jar in ws-launch.jar ws-server.jar; do
    PS_MATCH=$(ps aux | grep java | grep "${curr}" | grep $jar | grep javaagent | grep -v grep)
    if [ -n "$PS_MATCH" ]; then
	  # Echo processes into build log (stdout)
      echo "$PS_MATCH"
	pids=$(ps aux | grep java | grep $PWD | grep $jar | grep javaagent | grep -v grep | awk '{print $2}')
	for pid_x in $pids
	do
	  kill -9 ${pid_x}
	done
	else
      echo "No previous $jar processes found"
    fi
done
sleep 3

# run this from the <build>/wlp dir of a new Liberty build
targDir=${sufpScriptDir}/apps

setMongo="export MONGO_HOST=${MONGO_HOST}"
$setMongo

arg=$1
if [[ ! -z $arg ]] ; then
	if [[ "$arg" == "ee8" ]] ; then
		targDir=${sufpScriptDir}/apps-ee8/
	else
		echo "unknown arg $arg ignored"
	fi
fi

echo "*** installing app from $targDir ***"
sleep 5

#numaargs="numactl --physcpubind 6-7,14-15"
numaargs="numactl --physcpubind ${PHYS_CPU_BIND}"

$numaargs ./bin/server create ${APP}  
/usr/bin/cp -f ${targDir}/${APP}/server.xml usr/servers/${APP}/
/usr/bin/cp -f ${targDir}/${APP}/server.env usr/servers/${APP}/
#Edit server.xml to point to app location
sed -i "s|\"/sufp/apps|\"${targDir}|g" usr/servers/${APP}/server.xml  
test=$(echo ${targDir}/${APP} | sed -e "s/\// /g")
if [[ `echo $test | grep spring ` ]] ; then
	mkdir usr/servers/${APP}/dropins/spring
	cp ${targDir}/${APP}/*.jar usr/servers/${APP}/dropins/spring
fi
$numaargs ./bin/server start ${APP}  
sleep 30
$numaargs ./bin/server stop ${APP}  

echo "Finished App: ${APP} setup"

$numaargs grep ERROR ./usr/servers/*/logs/console.log | grep -v  "huge-ejb.*SRVE9967W.*manifest class path.*can not be found"
$numaargs grep FFDC1015I ./usr/servers/*/logs/messages.log
