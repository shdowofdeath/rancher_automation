#!/usr/bin/env bash
JQ_URL="https://github.com/shdowofdeath/rancher_automation/raw/master/jq-linux64"
KCTL_VERSION="https://github.com/shdowofdeath/rancher_automation/raw/master/kubectl"
CONTEXT_REQ="https://github.com/shdowofdeath/rancher_automation/raw/master/requirements.txt"
GET_CONTEXT="https://github.com/shdowofdeath/rancher_automation/raw/master/get_context_from_rancher.py"
DEST_BIN="/usr/bin/jq"
RANCHER_VERION="rancher/rancher:latest"
PORT="9443"
USERNAME="admin"
PASSWORD="password"
HOSTNAME_IP=`hostname -I | cut -d' ' -f1`
RANCHERSERVER_VER="v1.14.5-rancher1-1"
AGENT_VERSION='v2.2.7'
CLEANUP="true"

  
function cleanup(){
    #cleanning dockers 
    while [ `docker ps -a  | grep -v CONTAINER | awk '{print $1}'   | wc -l` != 0  ] ; do 
      docker ps -a  | awk '{print $1}' | xargs -I whatisit docker stop whatisit
      docker ps -a  | awk '{print $1}' | xargs -I whatisit docker rm -f whatisit
    done
    
    #docker images | awk '{print $3}' | xargs -I whatisit docker rmi -f whatisit
    
    #cleanning volumes 
    while [ `docker volume ls | grep -v VOLUME  | awk '{print $1}' | wc -l ` != 0 ] ; do 
     docker volume ls  | grep -v VOLUME  | awk '{print $2}' | xargs -I whatisit docker volume rm whatisit
    done 
    sudo rm -rf /var/lib/calico /etc/kubernetes /var/lib/etcd /var/lib/rancher /var/lib/cni

}

function install_rancher(){
    docker run -d --name rancher-server --restart=unless-stopped -p 9080:80 -p 9443:443 ${RANCHER_VERION}
}

function instal_jq(){
            if [ `jq --version | wc -l` != 1 ] ; then
             echo "installing jq "
             wget -O ${DEST_BIN} ${JQ_URL}
             chmod 777 ${DEST_BIN}
            else
             echo 'jq installed '
            fi
}


function rancher_validation() {
     # Validate ip
     HOSTNAME_IP=`hostname -I | cut -d' ' -f1`
     # # Validate connectivity
     while ! curl -k --noproxy "*" https://127.0.0.1:9443/ping; do echo "wait for rancher to be up " ; sleep 3; done

}

function rancher_configuration() {
      # Validate ip
      HOSTNAME_IP=`hostname -I | cut -d' ' -f1`
      # Validate connectivity
      while ! curl --noproxy "*" -k https://127.0.0.1:9443/ping; do sleep 3; done
      # Login
      LOGINRESPONSE=`curl --noproxy "*" -s 'https://127.0.0.1:9443/v3-public/localProviders/local?action=login' -H 'content-type: application/json' --data-binary '{"username":"admin","password":"admin"}' --insecure`
      LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
      # Change password
      curl -s --noproxy "*" 'https://127.0.0.1:9443/v3/users?action=changepassword' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"currentPassword":"admin","newPassword":"'$PASSWORD'"}' --insecure
      # Create API key
      APIRESPONSE=`curl -s --noproxy "*" 'https://127.0.0.1:9443/v3/token' -H 'content-type: application/json' -H "Authorization: Bearer $LOGINTOKEN" --data-binary '{"type":"token","description":"automation"}' --insecure`
      # Extract and store token
      APITOKEN=`echo $APIRESPONSE | jq -r .token`
      # Set server-url
      RANCHER_SERVER=https://${HOSTNAME_IP}:9443
      curl -s --noproxy "*" 'https://${RANCHER_SERVER}/v3/settings/server-url' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" -X PUT --data-binary '{"name":"server-url","value":"'$RANCHER_SERVER'"}' --insecure 
      # Create cluster
      echo $RANCHERSERVER_VER > /tmp/test_local
      cat /tmp/test_local
      CLUSTERRESPONSE=`curl -s --noproxy "*" 'https://127.0.0.1:9443/v3/cluster' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"cluster","nodes":[],"rancherKubernetesEngineConfig":{"ignoreDockerVersion":true , "kubernetesVersion":"'$RANCHERSERVER_VER'"},"name":"local"}' --insecure`
      # Extract clusterid to use for generating the docker run command
      CLUSTERID=`echo $CLUSTERRESPONSE | jq -r .id`
  
  
      # Generate docker run
      AGENTIMAGE=`curl -s --noproxy "*" -H "Authorization: Bearer $APITOKEN" https://127.0.0.1:9443/v3/settings/agent-image --insecure | jq -r .value`
      ROLEFLAGSADMIN="--etcd --controlplane --worker"
      ROLEFLAGS="--worker"
      RANCHERSERVER="https://$HOSTNAME_IP:9443"
      # Generate token (clusterRegistrationToken)
      AGENTTOKEN=`curl -s --noproxy "*" 'https://127.0.0.1:9443/v3/clusterregistrationtoken' -H 'content-type: application/json' -H "Authorization: Bearer $APITOKEN" --data-binary '{"type":"clusterRegistrationToken","clusterId":"'$CLUSTERID'"}' --insecure | jq -r .token`
      # Retrieve CA certificate and generate checksum
      CACHECKSUM=`curl -s --noproxy "*" -H "Authorization: Bearer $APITOKEN" https://127.0.0.1:9443/v3/settings/cacerts --insecure | jq -r .value | sha256sum | awk '{ print $1 }'`
      # Assemble the docker run command
      AGENTCOMMAND="docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run  rancher/rancher-agent:$AGENT_VERSION--server $RANCHERSERVER --token $AGENTTOKEN --ca-checksum $CACHECKSUM $ROLEFLAGS"
      AGENTCOMMANDADMIN="docker run -d --privileged --restart=unless-stopped --net=host -v /etc/kubernetes:/etc/kubernetes -v /var/run:/var/run  rancher/rancher-agent:$AGENT_VERSION --server $RANCHERSERVER --token $AGENTTOKEN --ca-checksum $CACHECKSUM $ROLEFLAGSADMIN"
      # Show the command
      echo $AGENTCOMMANDADMIN > /tmp/rancher_admin
      echo $AGENTCOMMAND > /tmp/rancher_login
      cat /tmp/rancher_login

}

function init_node(){
      echo "validaing that token master been created "
      bash /tmp/rancher_admin >> /tmp/logs_rancher_admin
      echo " valiate log file for master is been created !!"
      cat /tmp/logs_rancher_admin

}


function install_kubectl(){
    curl -LO ${KCTL_VERSION}
    chmod +x ./kubectl
    sudo cp ./kubectl /usr/local/bin/kubectl
    sudo cp ./kubectl /usr/bin/kubectl
}

function validate_kubectl(){
    get_client=`kubectl version | grep Client  | wc -l`
    if [ ${get_client} ==  1 ] ; then
        echo "kubectl - no need to install "
    else
        echo "kubectl - needed to be installed"
        install_kubectl
    fi

}



function cleanup_after_init(){
    docker ps -a | grep -i exit | awk '{print $1}' |xargs -I cleaner docker rm -f cleaner

}

function create_context(){
    wget $CONTEXT_REQ
    wget $GET_CONTEXT


}

function validate_cluster_is_up(){
        echo "waiting for cluster to be up < please wait and drink something meanwhile :) "
        timeValid=0
        validate_cluster_status=`docker logs rancher-server | grep -i 'cluster successfully' | wc -l`
	while [ $validate_cluster_status != 1 ] ; do 
          validate_cluster_status=`docker logs rancher-server | grep -i 'cluster successfully' | wc -l`
          ((timeValid++)) 
	done 
        echo "time validation: $timeValid"



}


function get_context(){
    pip install -r requirements.txt
    python get_context_from_rancher.py -u admin -p ${PASSWORD} -i 127.0.0.1 -o 9443 -c local
    echo "Your cluster is ready to use , enjoy and don't brake it :) " 
    echo "To access please login with username admin , passowrd : ${PASSWORD} to https://`hostname -I | cut -d' ' -f1`:9443"
}

if [ ${CLEANUP} = "true" ] ; then
    cleanup
    echo "all clean " 
    sleep 1s
fi


function install_helm(){
      # Extract kubeconfig  
  curl --insecure -u "$APITOKEN" -X POST -H 'Accept: application/json' -H 'Content-Type: application/json' 'https://127.0.0.1:9443/v3/clusters/'$CLUSTERID'?action=generateKubeconfig'  | jq -r .config > ~/.kube/config 
  echo " after create context run it "
	kubectl -n kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
  helm init --service-account tiller --override spec.selector.matchLabels.'name'='tiller',spec.selector.matchLabels.'app'='helm' --output yaml | sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@' | kubectl apply -f -
	

}


install_rancher
rancher_validation
sleep 45s
rancher_configuration
init_node
validate_cluster_is_up
echo " please login to ui validate everything is working now "
sleep 45s
install_helm
