curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add minio https://helm.min.io
kubectl apply -f minionamespace.yaml
helm install --namespace minio --generate-name minio/minio --set persistence.storageClass=sc-common
