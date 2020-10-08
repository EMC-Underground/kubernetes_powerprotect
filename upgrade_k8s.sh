#!/bin/usr/env bash

export BRANCH="master"
#############################################
# Load in the config file
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/config)

#############################################
# Load in the generate file
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/generate)

#############################################
# Load in the software check functions
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/software_checks)

#############################################
# Load in the vault related functions
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/vault)

#############################################
# Load in the concourse related functions
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/concourse)

#############################################
# Load in the input related functions
#############################################
source <(curl -fsSL https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/bin/input)

pull_repo() {
    local repo_url=$1 repo_name=`echo $1 | awk -F'/' '{print $NF}' | awk -F'.' '{print $1}'`
    printf "${cyan}Cloning ${repo_name} repo.... "
    if [ -d "/tmp/${repo_name}" ]
    then
        rm /tmp/$repo_name > /dev/null 2>&1
    fi
    git clone $repo_url /tmp/$repo_name > /dev/null 2>&1
    success
}

generate_repo_url() {
    local src_url=$1 repo_user=$2 repo_name=$3
    if [[ ssh_repos -eq 0 ]]
    then
        printf "git@${src_url}:${repo_user}/${repo_name}.git"
    else
        printf "https://${src_url}/${repo_user}/${repo_name}.git"
    fi
}


kubernetes_version=`kubectl version --short | awk 'END{print $3}'`
apt update
apt-mark unhold kubeadm
apt install -y kubeadm=1.15.12-00
apt-mark hold kubadm

pull_repo `generate_repo_url "github.com" "EMC-Underground" "kubernetes_powerprotect"
