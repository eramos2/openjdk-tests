#!/usr/bin/env bash
# Array of all the apps to setup/run
#apps=(acmeair-micro acmeair-mono cdi-base cdi-fat cdi-one-jar-fat dt7 dt8 huge-ejb javaee7 javaee8 jaxrs-fat jenkins micro-profile-3 no-app no-feat petclinic pingperf spring-1.5.6 spring-2.1.1 tradelite7 tradelite8 webProfile7 webProfile8)
#apps=(dt7)
echo $apps
sufpScriptDir=$1

echo "about to kill all java procs, unless you stop me in next 10 secs"
sleep 15
#killall -9 java
pkill -f "/WPA_INST*"
# run this from the <build>/wlp dir of a new Liberty build
targDir=${sufpScriptDir}/apps

setMongo="export MONGO_HOST=titans08"
$setMongo

arg=$1
if [[ ! -z $arg ]] ; then
	if [[ "$arg" == "ee8" ]] ; then
		targDir=${sufpScriptDir}/apps-ee8/
	else
		echo "unknown arg $arg ignored"
	fi
fi

echo "*** installing apps from $targDir ***"
sleep 5

numaargs="numactl --physcpubind 6-7,14-15"
#export JAVA_HOME=/opt/java/j9-828-sr5-fp17/jre 
#export JAVA_HOME=/opt/java/j9-828-sr6-fp0/jre 
#export JAVA_HOME=/opt/java/j9-828-sr6-fp5/jre
#export JAVA_HOME=/opt/java/j9-828-sr6-fp6ifix/jre
#export JAVA_HOME=/opt/java/j9-828-sr6-fp7/jre

#for app in `ls /sufp/apps/` 
## Original way of doing the setup
#for app in `ls $targDir` 
for app in "${apps[@]}";
do 
	$numaargs ./bin/server create $app  
	/usr/bin/cp -f ${targDir}/${app}/server.xml usr/servers/${app}/
	#Edit server.xml to point to app location
	sed -i "s|\"/sufp/apps|\"${targDir}|g" usr/servers/${app}/server.xml  
	test=`echo ${targDir}/${app} | sed -e "s/\// /g"`
	if [[ `echo $test | grep spring ` ]] ; then
		mkdir usr/servers/${app}/dropins/spring
		cp ${targDir}/${app}/*.jar usr/servers/${app}/dropins/spring
	fi
	$numaargs ./bin/server start $app  
#	vim usr/servers/${app}/logs/console.log  
#	vim usr/servers/${app}/logs/messages.log  
	sleep 30
	$numaargs ./bin/server stop $app  
done

$numaargs grep ERROR ./usr/servers/*/logs/console.log | grep -v  "huge-ejb.*SRVE9967W.*manifest class path.*can not be found"
$numaargs grep FFDC1015I ./usr/servers/*/logs/messages.log

