helm repo add minio https://helm.min.io
kubectl apply -f minionamespace.yaml
helm install --namespace minio --generate-name minio/minio --set persistence.storageClass=sc-common
