#!/bin/usr/env bash

export BRANCH="master"
#############################################
# Load in the config file
#############################################
source bin/config

#############################################
# Load in the software check functions
#############################################
source bin/software_checks

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

main() {
  software_pre_reqs
}

main
