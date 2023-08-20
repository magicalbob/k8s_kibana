# create kibana namespace, if it doesn't exist
kubectl get ns kibana 2> /dev/null
if [ $? -eq 1 ]
then
    kubectl create namespace kibana
fi

# create kibana deployment
kubectl apply -f kibana.yml
