cd #!/bin/bash
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
echo FIRSTMDMIP    = "${FIRSTMDMIP}"
echo SECONDMDMIP    = "${SECONDMDMIP}"
echo TBIP    = "${TBIP}"
echo PASSWORD    = "${PASSWORD}"
echo CLUSTERINSTALL   =  "${CLUSTERINSTALL}"
echo SVM   =  "${SVM}"
echo SVMDOWNLOAD    = "${SVMDOWNLOAD}"
echo SVMSERVER    = "${SVMSERVER}"

#echo "Number files in SEARCH PATH with EXTENSION:" $(ls -1 "${SEARCHPATH}"/*."${EXTENSION}" | wc -l)
truncate -s 100GB ${DEVICE}
yum install numactl libaio -y

#install securevm packages if needed
echo "Installing SecureVM Packages"
yum install parted -y
yum install wget -y
yum install cryptsetup -y
yum install rsync -y

cd /vagrant/scaleio2

if [ "${CLUSTERINSTALL}" == "True" ]; then
  echo "Instaling MDM, SDS and SDC"
  MDM_ROLE_IS_MANAGER=1 rpm -i ${PACKAGENAME}-mdm-${VERSION}.${OS}.x86_64.rpm
  sleep 10
  rpm -i ${PACKAGENAME}-sds-${VERSION}.${OS}.x86_64.rpm
  sleep 10
  MDM_IP=${FIRSTMDMIP},${SECONDMDMIP} rpm -i ${PACKAGENAME}-sdc-${VERSION}.${OS}.x86_64.rpm

  echo "Creating cluster"
  scli --create_mdm_cluster --master_mdm_ip ${SECONDMDMIP} --master_mdm_management_ip ${SECONDMDMIP} --master_mdm_name mdm2 --accept_license --approve_certificate
  echo "Waiting 10 seconds to ensure services ready"
  sleep 10
  
  echo "Logging in"
  scli --login --username admin --password admin --approve_certificate
  
  echo "Changing Password"
  scli --set_password --old_password admin --new_password ${PASSWORD}
  
  echo "Logging in and adding MDM1 as standby"
  scli --login --username admin --password ${PASSWORD}
  scli --add_standby_mdm --new_mdm_ip ${FIRSTMDMIP} --mdm_role manager --new_mdm_management_ip ${FIRSTMDMIP} --new_mdm_name mdm1
  echo "Logging in and adding td as tb"
  scli --add_standby_mdm --new_mdm_ip ${TBIP} --mdm_role tb --new_mdm_name tb
  echo "Cluster Details before 3 node cluster setup"
  scli --query_cluster
  
  echo "Swithcing to 3 node cluster" 
  scli --switch_cluster_mode --cluster_mode 3_node --add_slave_mdm_name mdm1 --add_tb_name tb1
  echo "Cluster Details"
  scli --query_cluster
  echo "Waiting for 15 seconds, see latest cluster info above (should show 3 node cluster)"
  sleep 15
  echo "Logging in"
  scli --login --username admin --password ${PASSWORD}
  echo "Adding protectoin domain"
  scli --add_protection_domain --protection_domain_name pdomain
  echo "Adding storage pool"
  scli --add_storage_pool --protection_domain_name pdomain --storage_pool_name pool1
  echo "Adding 3 SDS"
  scli --add_sds --sds_ip ${FIRSTMDMIP} --device_path ${DEVICE} --sds_name sds1 --protection_domain_name pdomain --storage_pool_name pool1
  scli --add_sds --sds_ip ${SECONDMDMIP} --device_path ${DEVICE} --sds_name sds2 --protection_domain_name pdomain --storage_pool_name pool1
  scli --add_sds --sds_ip ${TBIP} --device_path ${DEVICE} --sds_name sds3 --protection_domain_name pdomain --storage_pool_name pool1
  echo "Waiting for 30 seconds to make sure the SDSs are created"
  sleep 30
  echo "Logging in"
  scli --login --username admin --password ${PASSWORD}
  echo "Adding volume"
  scli --add_volume --size_gb 8 --volume_name vol1 --protection_domain_name pdomain --storage_pool_name pool1
  echo "Mapping volume locally"
  #scli --map_volume_to_sdc --volume_name vol1 --sdc_ip ${FIRSTMDMIP} --allow_multi_map
  scli --map_volume_to_sdc --volume_name vol1 --sdc_ip ${SECONDMDMIP}
  #scli --map_volume_to_sdc --volume_name vol1 --sdc_ip ${TBIP} --allow_multi_map
  
fi

echo SVMDOWNLOAD    = "${SVMDOWNLOAD}"
echo SVMSERVER    = "${SVMSERVER}"


#Install SecureVM
if [ "${SVM}" == "True" ]; then
  echo "Downloading SecureVM"
  
  #ensure fresh download of the script
   rm -f securevm*.*
  
  wget ${SVMDOWNLOAD}
  chmod +x securevm
  ./securevm -S ${SVMSERVER}

  #automates the encryption if needed for SDC 
  #echo "Formatting SDC EXT3"
  #mkfs.ext3 /dev/scinia
  #echo "Format Complete"
  #mkdir /datavol1
  #echo "Mounting SDC to /datavol1"
  #mount /dev/scinia /datavol1
  #echo "Encrypting /datavol1, please wait.  Please ensure the VM is approved if needed on CloudLink center"
  #svm encrypt /datavol1 /dev/scinia
fi

if [[ -n $1 ]]; then
  echo "Last line of file specified as non-opt/last argument:"
  tail -1 $1
fi

