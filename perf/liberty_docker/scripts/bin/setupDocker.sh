#!/bin/bash
MP_RELEASE=${1}

export JAVA_HOME=/opt/ibm/java_8_6_test/sdk

rm -rf /opt/docker-automated/git
mkdir -p /opt/docker-automated/git
cd /opt/docker-automated/git


case ${MP_RELEASE} in

microProfile-1.0)
 BRANCH="-b microprofile-1.0" 
 ;;
microProfile-1.4)
 BRANCH="-b microprofile-1.4"
 ;;
microProfile-2.0)
 BRANCH="-b microprofile-2.0"
 ;;
microProfile-2.2)
 BRANCH="-b microprofile-2.2"
 ;;
microProfile-3.0)
 BRANCH="-b microprofile-3.0"
 ;;
microProfile-3.2)
 BRANCH="-b microprofile-3.2"
 ;;
microProfile-3.3)
 BRANCH=""
 ;;
esac


echo "Clone ${BRANCH}"
git clone ${BRANCH} https://github.com/BluePerf/acmeair-mainservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-authservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-bookingservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-customerservice-java.git
git clone ${BRANCH} https://github.com/BluePerf/acmeair-flightservice-java.git

echo "Build java"
cd acmeair-mainservice-java
mvn clean package

cd ../acmeair-authservice-java
mvn clean package

cd ../acmeair-bookingservice-java
mvn clean package

cd ../acmeair-customerservice-java
mvn clean package

cd ../acmeair-flightservice-java
mvn clean package

cd ..

cp /opt/docker-scripts/files/docker-compose-${MP_RELEASE}.yml /opt/docker-automated/git/acmeair-mainservice-java/docker-compose.yml

# hack for now, may need to update java.security file occasionally
if [[ "${2}" == *true* ]] 
then

  echo " enabling jce plus"
  cp /opt/docker-scripts/files/java.security acmeair-authservice-java/
  cp /opt/docker-scripts/files/java.security acmeair-bookingservice-java/
  cp /opt/docker-scripts/files/java.security acmeair-customerservice-java/

  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-authservice-java/Dockerfile-daily
  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-bookingservice-java/Dockerfile-daily
  echo "COPY java.security /opt/ibm/java/jre/lib/security/java.security" >> acmeair-customerservice-java/Dockerfile-daily

fi
