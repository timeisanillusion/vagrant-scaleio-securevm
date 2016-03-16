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
    -t|--tbip)
    TBIP="$2"
    shift
	;;
    -p|--password)
    PASSWORD="$2"
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
echo TBIP    = "${TBIP}"
echo FIRSTMDMIP    = "${FIRSTMDMIP}"
echo SECONDMDMIP    = "${SECONDMDMIP}"
echo SVM   =  "${SVM}"
echo SVMDOWNLOAD    = "${SVMDOWNLOAD}"
echo SVMSERVER    = "${SVMSERVER}"


#echo "Number files in SEARCH PATH with EXTENSION:" $(ls -1 "${SEARCHPATH}"/*."${EXTENSION}" | wc -l)
truncate -s 100GB ${DEVICE}
yum install numactl libaio -y
yum install java-1.7.0-openjdk -y

#install securevm packages if needed
echo "Installing SecureVM Packages"
yum install parted -y
yum install wget -y
yum install cryptsetup -y
yum install rsync -y

cd /vagrant/scaleio2

# Always install ScaleIO IM
#export GATEWAY_ADMIN_PASSWORD=${PASSWORD}
#rpm -Uv ${PACKAGENAME}-gateway-${VERSION}.noarch.rpm

if [ "${CLUSTERINSTALL}" == "True" ]; then
  MDM_ROLE_IS_MANAGER=1 rpm -i ${PACKAGENAME}-mdm-${VERSION}.${OS}.x86_64.rpm
  sleep 10
  rpm -i ${PACKAGENAME}-sds-${VERSION}.${OS}.x86_64.rpm
  #MDM_IP=${FIRSTMDMIP},${SECONDMDMIP} rpm -i ${PACKAGENAME}-sdc-${VERSION}.${OS}.x86_64.rpm
  
fi

#sed -i 's/mdm.ip.addresses=/mdm.ip.addresses='${FIRSTMDMIP}','${SECONDMDMIP}'/' /opt/emc/scaleio/gateway/webapps/ROOT/WEB-INF/classes/gatewayUser.properties
#service scaleio-gateway restart


if [ "${SVM}" == "True" ]; then
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
