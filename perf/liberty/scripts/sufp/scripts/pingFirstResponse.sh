#!/bin/bash

testHost=$1
if [[ -z $testHost ]]  ; then echo "must specify test host name" ; exit 99 ; fi
shift

testPort=$1
if [[ -z $testPort ]]  ; then echo "must specify test port name" ; exit 99 ; fi
shift

testTarget=$1
if [[ -z $testTarget ]]  ; then echo "must specify test target name" ; exit 99 ; fi
shift

respFile=$1
if [[ -z $respFile ]]  ; then echo "must specify respMillisFile" ; exit 99 ; fi
shift

testRequest="${testHost}:${testPort}${testTarget}"
#echo "testRequest: $testRequest"

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' ${testRequest})" != "200" ]]; do 

	sleep 0.001; 

done

respMillis=`echo $(($(date +%s%N)/1000000))`
#echo "respMillis: $respMillis"
echo "$respMillis" > $respFile
