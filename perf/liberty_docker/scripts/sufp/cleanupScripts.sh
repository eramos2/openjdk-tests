#!/bin/bash

targ=$1

if [[ -z $targ ]] ; then echo "must specify target script" ; exit 99 ; fi

ps -ef | grep "${targ}" | grep -v grep | awk '{print $2}' | xargs kill -9 
