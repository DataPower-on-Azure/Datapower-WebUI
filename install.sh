#!/bin/bash

echo "Attempting to login to cluster using oc whoami"
USER=$(oc whoami)

if [ $? -eq 0 ]
then
    echo "Logged into a cluster"
    printf "User: "
    tput setaf 2
    echo $USER
    tput sgr0
    echo
else
    echo "Not logged into a cluster. Please login using 'oc login'"
    exit 1
fi

#Check the user is set to the correct project
echo "Please check you are using the correct project"
echo `oc project`
while true; do
    read -p "Is this the correct project? (Y/N) " yn
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit 1;;
        * ) echo "Please answer yes or no.";;
    esac
done


if [ -d "./generated-certs" ]
then
    echo "\nError: 'generated-certs' directory already exists"
    while true; do
        read -p "Would you like to overwrite? (Y/N) " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) echo "Exiting";exit 1;;
            * ) echo "Please answer yes or no.";;
        esac
     done
fi

read -p "Please enter the password you want for admin: " PASSWORD

read -p "Enter name of deployment (default webgui-deployment): " DEPLOYMENT_NAME
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-webgui-deployment}

read -p "Enter name of domain config (default domain-config): " DOMAIN_CONFIG_NAME
DOMAIN_CONFIG_NAME=${DOMAIN_CONFIG_NAME:-domain-config}

read -p "Enter name of domain user secret (default datapower-user): " DATAPOWER_USER_SECRET
DATAPOWER_USER_SECRET=${DATAPOWER_USER_SECRET:-datapower-user}

read -p "Enter name of datapower certificate secret (default datapower-cert): " DATAPOWER_CERT_NAME
DATAPOWER_CERT_NAME=${DATAPOWER_CERT_NAME:-datapower-cert}

mkdir -p generated-certs
cd generated-certs

openssl genrsa -out myCA.key 2048

openssl req -x509 -new -nodes -key myCA.key -sha256 -days 1825 -out myCA.pem -subj /CN=GB

cd ..

oc patch -f manifests/datapower.yaml --type "json" -p "[{'op': 'replace', 'path': '/metadata/name','value':'$DEPLOYMENT_NAME'}, {'op': 'replace', 'path': '/spec/labels/app','value':'$DEPLOYMENT_NAME'},{'op': 'replace', 'path': '/spec/domains/0/dpApp/config/0','value':'$DOMAIN_CONFIG_NAME'},{'op': 'replace', 'path': '/spec/domains/0/certs/0/secret','value':'$DATAPOWER_CERT_NAME'},{'op': 'replace', 'path': '/spec/users/0/passwordSecret','value':'$DATAPOWER_USER_SECRET'}]" --dry-run=client -o yaml > manifests/datapower-manifest.yaml

oc patch -f manifests/domain-config.yaml --type "json" -p "[{'op': 'replace', 'path': '/metadata/name','value':'$DOMAIN_CONFIG_NAME'}]" --dry-run=client -o yaml > manifests/domain-config-manifest.yaml

oc create service clusterip $DEPLOYMENT_NAME --tcp=9090:9090

oc create route reencrypt $DEPLOYMENT_NAME --service=$DEPLOYMENT_NAME --dest-ca-cert generated-certs/myCA.pem

oc create secret generic $DATAPOWER_USER_SECRET --from-literal=password=$PASSWORD

oc create secret generic $DATAPOWER_CERT_NAME --from-file=generated-certs/myCA.pem --from-file=generated-certs/myCA.key

oc apply -f manifests/domain-config-manifest.yaml

oc apply -f manifests/datapower-manifest.yaml

COUNT=30;
while [[ "$(oc get DataPowerService $DEPLOYMENT_NAME  -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}')" != "True" ]]
do  
    if  [ $COUNT -le 1 ]
    then 
        echo "timeout waiting for pods"
        exit 1
    else
        COUNT=$(( $COUNT - 1 ))
        echo "waiting for pod, trying $COUNT more times" && sleep 10; 
    fi
done

ROUTE_URL=$(oc get route $DEPLOYMENT_NAME -o jsonpath='{.spec.host}')

echo "Route URL is: https://$ROUTE_URL"