#!/bin/bash
echo "deploying metal-lb"
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f metal-lb-config.yaml
read -p "Press any key to continue"

echo "deploying contour+envoy"
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
read -p "Press any key to continue"

echo "applying the wordpressnamespace yaml"
kubectl apply -f wordpressnamespace.yaml
kubectl get ns
read -p "Press any key to continue"

echo "Installing WordPress Using Helm"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install wordpresstest bitnami/wordpress --namespace wordpresssbux01
kubectl get pods -n wordpresssbux01
read -p "Press any key to continue"

echo "Lets go checkout the backup!"
kubectl apply -f restore-wordpress-to-new.yaml
kubectl get restorejobs -n powerprotect wordpressrestore -o yaml
read -p "Press any key to continue"

echo "Lets go see if the restore worked!"
kubectl get pods wordpresstest01-restored
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

