#!/usr/bin/env bash
testHost=$1
if [[ -z $testHost ]]  ; then echo "must specify testhost name" ; exit 99 ; fi
testRequest="${testHost}:9080/pingperf/ping/greeting"
echo "testRequest: $testRequest"
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' ${testHost}:9080/pingperf/ping/greeting)" != "200" ]]; do 
	sleep 0.001; 
done
