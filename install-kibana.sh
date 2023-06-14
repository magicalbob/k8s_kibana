# Make sure kind cluster exists
kind  get clusters 2>&1 | grep "kind-kibana"
if [ $? -gt 0 ]
then
    envsubst < kind-config.yml.template > kind-config.yml
    kind create cluster --config kind-config.yml --name kind-kibana
fi

# Make sure create cluster succeeded
kind  get clusters 2>&1 | grep "kind-kibana"
if [ $? -gt 0 ]
then
    echo "Creation of cluster failed. Aborting."
    exit 666
fi

# add metrics
kubectl apply -f https://dev.ellisbs.co.uk/files/components.yaml

# install local storage
kubectl apply -f  local-storage-class.yml

# create kibana namespace, if it doesn't exist
kubectl get ns kibana 2> /dev/null
if [ $? -eq 1 ]
then
    kubectl create namespace kibana
fi

# sort out persistent volume
export NODE_NAME=$(kubectl get nodes |grep control-plan|cut -d\  -f1)
envsubst < kibana.pv.yml.template > kibana.pv.yml
kubectl apply -f kibana.pv.yml

# Do rest of applies
kubectl apply -f es01-service.yml
kubectl apply -f es01-deployment.yml
kubectl apply -f es02-service.yml
kubectl apply -f es02-deployment.yml
kubectl apply -f kibana-service.yml
kubectl apply -f kibana-deployment.yml

# check status
kubectl get all -n kibana
