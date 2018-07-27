#!/bin/bash
set -eo pipefail

OS=$(uname -a | awk '{print $1}')
if [ "${OS}" = "Darwin" ]
then
  function getent {
    name=$(dscacheutil -q host -a name $2 | grep name |  awk '{print $2}');
    addr=$(dscacheutil -q host -a name $2 | grep ip_address | awk '{print $2}')
    echo "${addr}       ${name}"
  }
fi

nfs_docker_path="/zm-nfs"
nfs_host_path="/zm-nfs"

s3_bucket="zoneminder-rpi3cameras"
zm_pod_basename="zoneminder-rpi3cameras"


#--------------------------------------------------------
is_zm_exist=`kubectl get pod`
if [[ $is_zm_exist = *"zm-server"* ]]; then
    echo "[`date`] - ZoneMinder has been deployed. Exit deploy."
    exit 1
fi
echo "[`date`] - Deploy ZoneMinder Start"


#--------------------------------------------------------
# NFS
#--------------------------------------------------------
echo "[`date`] - set zm_nfs yaml"
echo "[`date`] - nfs host path = ${nfs_host_path}"
echo "[`date`] - nfs docker path = ${nfs_docker_path}"
nfs_export_path=${nfs_docker_path}
nfs_docker_path=`echo ${nfs_docker_path} |  sed 's:\/:\\\/:g'`
nfs_host_path=`echo ${nfs_host_path} |  sed 's:\/:\\\/:g'`

cp -afpR ./zm_nfs.yaml.tpl ./zm_nfs.yaml

sed -i '' "s/_SMB_SERVER_/0/g"                   ./zm_nfs.yaml
sed -i '' "s/_NFS_SERVER_/1/g"                   ./zm_nfs.yaml
sed -i '' "s/_DOCKER_PATH_/${nfs_docker_path}/g" ./zm_nfs.yaml
sed -i '' "s/_HOST_PATH_/${nfs_host_path}/g"     ./zm_nfs.yaml

echo "[`date`] - kubectl create zm_nfs"
kubectl create -f ./zm_nfs.yaml

sleep 2
zm_nfs_pod_name=`kubectl get pod | grep 'zm-nfs-' | awk '{print $1}'`
echo "[`date`] - zm_nfs pod name is ${zm_nfs_pod_name}"

while true; do
    zm_nfs_pod_status=`kubectl get pod | grep 'zm-nfs-' | awk '{print $3}'`
    if [[ "${zm_nfs_pod_status}" == "Running" ]]; then
        echo "[`date`] - zm_nfs pod is running."
        break
    fi
    echo "[`date`] - zm_nfs pod is in ${zm_nfs_pod_status}"
    sleep 5
done

echo "[`date`] - config zm_nfs server"
kubectl exec -ti ${zm_nfs_pod_name} config-nfs add ${nfs_export_path} '*(rw,fsid=0,nohide,insecure,async,no_subtree_check,no_root_squash)'
kubectl exec -ti ${zm_nfs_pod_name} server-run
kubectl exec -ti ${zm_nfs_pod_name} server-run status
echo "[`date`] - config zm_nfs server done"

nfs_hostport=`kubectl get svc | grep "zm-nfs" | awk '{print $5}' | cut -d: -f 2 | cut -d/ -f 1`
nfs_hostname=`kubectl get pod -o wide | grep "zm-nfs-" | awk '{print $7}'`
nfs_hostip=`getent hosts ${nfs_hostname} | awk '{print $1}'`
echo "[`date`] - zm_nfs host ip:port = ${nfs_hostip}:${nfs_hostport}"


#--------------------------------------------------------
# Database
#--------------------------------------------------------
cp -afpR ./zm_db.yaml.tpl ./zm_db.yaml

echo "[`date`] - kubectl create zm_db"
kubectl create -f ./zm_db.yaml

sleep 2
zm_db_pod_name=`kubectl get pod | grep 'zm-db' | awk '{print $1}'`
echo "[`date`] - zm_db pod name is ${zm_db_pod_name}"

while true; do
    zm_db_pod_status=`kubectl get pod | grep 'zm-db-' | awk '{print $3}'`
    if [[ "${zm_db_pod_status}" == "Running" ]]; then
        echo "[`date`] - zm_db pod is running."
        break
    fi
    echo "[`date`] - zm_db pod is in ${zm_db_pod_status}"
    sleep 5
done

db_hostport=`kubectl get svc | grep "zm-db" | awk '{print $5}' | cut -d: -f 2 | cut -d/ -f 1`
db_hostname=`kubectl get pod -o wide | grep "zm-db-" | awk '{print $7}'`
db_hostip=`getent hosts ${db_hostname} | awk '{print $1}'`
echo "[`date`] - zm_database host ip:port = ${db_hostip}:${db_hostport}"


#--------------------------------------------------------
# ZoneMinder
#--------------------------------------------------------
echo "[`date`] - set zm_server yaml"
cp -afpR ./zm_server.yaml.tpl ./zm_server.yaml

sed -i '' "s/_NFS_PORT_/${nfs_hostport}/g" ./zm_server.yaml
sed -i '' "s/_NFS_IP_/${nfs_hostip}/g" ./zm_server.yaml
sed -i '' "s/_DB_IP_/${db_hostip}/g" ./zm_server.yaml
sed -i '' "s/_DB_PORT_/${db_hostport}/g" ./zm_server.yaml

echo "[`date`] - kubectl create zm_server"
kubectl create -f ./zm_server.yaml

sleep 2
zm_server_pod_name=`kubectl get pod | grep "${zm_pod_basename}" | awk '{print $1}'`
echo "[`date`] - zm_server pod name is ${zm_server_pod_name}"

while true; do
    zm_server_pod_status=`kubectl get pod | grep "${zm_pod_basename}" | awk '{print $3}'`
    if [[ "${zm_server_pod_status}" == "Running" ]]; then
        echo "[`date`] - zm_server pod is running."
        break
    fi
    echo "[`date`] - zm_server pod is in ${zm_server_pod_status}"
    sleep 5
done

echo "[`date`] - Deploy ZoneMinder completed"


#--------------------------------------------------------
echo -e "\n----------------------------------------------------\n"
kubectl get svc,pod -o wide
