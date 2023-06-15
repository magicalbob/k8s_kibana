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

## sort out persistent volume - not used at the moment so sommented out for now
#export NODE_NAME=$(kubectl get nodes |grep control-plan|cut -d\  -f1)
#envsubst < kibana.pv.yml.template > kibana.pv.yml
#kubectl apply -f kibana.pv.yml

# Install custom resource definitions
kubectl create -f https://download.elastic.co/downloads/eck/2.8.0/crds.yaml

# Install the operator with its RBAC rules
kubectl apply -f https://download.elastic.co/downloads/eck/2.8.0/operator.yaml

# Install elasticsearch cluster
kubectl apply -f elasticsearch-cluster.yaml

# Wait for elastic search pod
until kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart' -n kibana 2>/dev/null  > /dev/null; do sleep 5; echo waiting; done
until kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart' -n kibana -o yaml|grep "phase: Running"; do sleep 5; echo waiting; done
kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart' -n kibana

# Setup port forward for elasticsearch cluster
while true; do
  # Check if kubectl port-forward is still running
  if ! pgrep -f "kubectl port-forward service/quickstart-es-http 9200 --address 127.0.0.1 -n kibana"; then
    echo "Relaunching 'kubectl port-forward'..."
    kubectl port-forward service/quickstart-es-http 9200 --address 127.0.0.1 -n kibana &
    sleep 5 # Give it a moment to start up
  fi

  # Your other script contents here...

  sleep 10 # Sleep for a while before checking again
done 2>&1 > /dev/null  &

# get password for the elasticsearch cluster
PASSWORD=$(kubectl get secret quickstart-es-elastic-user -n kibana -o go-template='{{.data.elastic | base64decode}}')

# curl the elasticsearch
until curl -fu "elastic:$PASSWORD" -k "https://127.0.0.1:9200" 2>/dev/null > /dev/null; do sleep 5; echo waiting; done
curl -u "elastic:$PASSWORD" -k "https://127.0.0.1:9200"

kubectl create configmap kibana-config --from-file=kibana.yml -n kibana
kubectl apply -f kibana.deployment.yaml
kubectl apply -f kibana.service.yaml
