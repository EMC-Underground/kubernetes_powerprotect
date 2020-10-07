Helm repo add minio https://helm.min.io
Helm install --namespace minio --generate-name --set persistence.storeageCall=sc-common
