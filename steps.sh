#!/bin/bash

echo "applying the wordpressnamespace yaml"
kubectl apply -f wordpressnamespace.yaml
kubectl get ns
read -p "Press any key to continue"
echo "Installing WordPress Using Helm"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install wordpresstest bitnami/wordpress --namespace wordpresssbux
kubectl get pods -n wordpresssbux
read -p "Press any key to continue"
echo "Lets go checkout the backup!"
kubectl apply -f restore-wordpress-to-new.yaml
#curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
#chmod 700 get_helm.sh
#./get_helm.sh
#helm repo add harbor https://helm.goharbor.io
#helm repo add bitnami https://charts.bitnami.com/bitnami
#kubectl apply -f harbornamespace.yaml
#kubectl apply -f sc-common.yaml
#kubectl apply -f mysql-sc.yaml
#kubectl create ns wordpress
#kubectl apply -f  wordpressnamespace.yaml
#helm install my-release harbor/harbor --namespace --set persistence.persistentVolumeClaim.redis.storageClass=demo-sc
#helm install --namespace minio --generate-name minio/minio --set persistence.storageClass=sc-common

