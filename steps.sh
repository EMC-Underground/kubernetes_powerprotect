curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
helm repo add harbor https://helm.goharbor.io
kubectl apply -f harbornamespace.yaml
kubectl apply -f sc-common.yaml
kubectl apply -f mysql-sc.yaml
helm install my-release harbor/harbor --namespace --set persistence.persistentVolumeClaim.redis.storageClass=demo-sc
helm install --namespace minio --generate-name minio/minio --set persistence.storageClass=sc-common
