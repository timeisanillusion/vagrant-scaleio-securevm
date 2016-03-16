#!/bin/bash
while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -o|--os)
    OS="$2"
    shift
    ;;
    -d|--device)
    DEVICE="$2"
    shift
    ;;
    -i|--installpath)
    INSTALLPATH="$2"
    shift
    ;;
    -v|--version)
    VERSION="$2"
    shift
    ;;
    -n|--packagename)
    PACKAGENAME="$2"
    shift
    ;;
    -f|--firstmdmip)
    FIRSTMDMIP="$2"
    shift
    ;;
    -s|--secondmdmip)
    SECONDMDMIP="$2"
    shift
    ;;
    -c|--clusterinstall)
    CLUSTERINSTALL="$2"
    shift
	;;
    -e|--svmserver)
    SVMSERVER="$2"
    shift
    ;;
    -w|--svmdownload)
    SVMDOWNLOAD="$2"
    shift
    ;;
    -k|--svm)
    SVM="$2"
    shift
	;;
    -j|--svms)
    SVMS="$2"
    shift
	;;
	-l|--svmspassword)
    SVMSPASSWORD="$2"
    shift
	;;
    *)
    # unknown option
    ;;
  esac
  shift
done
echo DEVICE  = "${DEVICE}"
echo INSTALL PATH     = "${INSTALLPATH}"
echo VERSION    = "${VERSION}"
echo OS    = "${OS}"
echo PACKAGENAME    = "${PACKAGENAME}"
echo FIRSTMDMIP    = "${FIRSTMDMIP}"
echo SECONDMDMIP    = "${SECONDMDMIP}"
echo CLUSTERINSTALL = "${CLUSTERINSTALL}"
echo SVM   =  "${SVM}"
echo SVMS   =  "${SVMS}"
echo SVMDOWNLOAD    = "${SVMDOWNLOAD}"
echo SVMSERVER    = "${SVMSERVER}"
echo SVMSERVERHTTP = "https://${SVMSERVER}"

#echo "Number files in SEARCH PATH with EXTENSION:" $(ls -1 "${SEARCHPATH}"/*."${EXTENSION}" | wc -l)
truncate -s 100GB ${DEVICE}
yum install numactl libaio wget -y
yum install java-1.7.0-openjdk -y


cd /vagrant




#version 2.0 download uncomment to download
#wget -nv ??????? -O ScaleIO_RHEL6_Download.zip
#unzip -o ScaleIO_RHEL6_Download.zip -d /vagrant/scaleio2


cd /vagrant/scaleio2

echo "Message bus check"
chkconfig messagebus on


if [ "${CLUSTERINSTALL}" == "True" ]; then
  echo "Install MDM"
  MDM_ROLE_IS_MANAGER=0 rpm -Uv ${PACKAGENAME}-mdm-${VERSION}.${OS}.x86_64.rpm
  sleep 10
  echo "Install SDS"
  rpm -Uv ${PACKAGENAME}-sds-${VERSION}.${OS}.x86_64.rpm
  sleep 10
  #MDM_IP=${FIRSTMDMIP},${SECONDMDMIP} rpm -i ${PACKAGENAME}-sdc-${VERSION}.${OS}.x86_64.rpm
fi


#Setup SecureVM Server
if [ "${SVMS}" == "True" ]; then
  echo "Downloading Packages Needed for API configuration"
  yum install nodejs -y
  yum install npm -y
  echo "Waiting 10 seconds"
  sleep 10
  npm -g install optimist request-promise bluebird
  echo "Waiting 10 seconds"
  sleep 10
  export NODE_PATH=/usr/lib/node_modules:$NODE_PATH
  export SVMLOC="${SVMSERVER}"
  echo "Downloading Latest Setup Script"
  rm -f wizard.js
  wget https://raw.githubusercontent.com/timeisanillusion/securevm-autodeploy/master/wizard.js
  rm -f license.lic
  wget https://raw.githubusercontent.com/timeisanillusion/securevm-autodeploy/master/license.lic
  
  
  echo "Running initial configuration"
  
  node wizard.js -a ${SVMSERVERHTTP} -w new -s ${SVMSPASSWORD}
  node wizard.js -a ${SVMSERVERHTTP} -w custom
  
fi


if [ "${SVM}" == "True" ]; then
  #install securevm packages if needed
  echo "Installing SecureVM Packages"
  yum install parted -y
  yum install wget -y
  yum install cryptsetup -y
  yum install rsync -y
  
  echo "Downloading SecureVM"
  
  #ensure fresh download of the script
   rm -f securevm*.*
  
  wget ${SVMDOWNLOAD}
  chmod +x securevm
  ./securevm -S ${SVMSERVER}
  
fi


if [[ -n $1 ]]; then
  echo "Last line of file specified as non-opt/last argument:"
  tail -1 $1
fi




