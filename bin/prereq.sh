#!/bin/bash

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
cyan=`tput setaf 6`
check="\xE2\x9C\x94"
cross="\xE2\x9C\x98"

print_check() {
    printf "${green}${check}\n${reset}"
}

print_cross() {
    printf "${red}${cross}\n${reset}"
}

success() {
    if [ $? -eq 0 ]
    then
        print_check
    else
        print_cross
        exit 1
    fi
}

yum_checks() {
    local tool="yum"
    local __resultvar=$1
    local result=1
    command -v $tool > /dev/null 2>&1 && [ -x $(command -v $tool) ]
    if [ $? -eq 0 ]
    then
        result=0
    fi
    eval $__resultvar="'$result'"
}

apt_checks() {
    local tool="apt-get"
    local __resultvar=$1
    local result=1
    command -v $tool > /dev/null 2>&1 && [ -x $(command -v $tool) ]
    if [ $? -eq 0 ]
    then
        result=0
    fi
    eval $__resultvar="'$result'"
}

ansible_checks() {
    local tool="ansible-playbook"
    local __resultvar=$1
    local result=1
    command -v $tool > /dev/null 2>&1 && [ -x $(command -v $tool) ]
    if [ $? -eq 0 ]
    then
        result=0
    fi
    eval $__resultvar="'$result'"
}

yum_steps() {
    printf "${cyan}Installing ansible with yum package manager.... ${reset}"
    sudo yum -y install epel-release > /dev/null 2>&1
    sudo yum -y install ansible > /dev/null 2>&1
    success
}

apt_steps() {
    printf "${cyan}Installing ansible with apt package manager.... ${reset}"
    sudo apt update > /dev/null 2>&1
    sudo apt -y install software-properties-common > /dev/null 2>&1
    sudo apt-add-repository --yes --update ppa:ansible/ansible > /dev/null 2>&1
    sudo apt -y install ansible > /dev/null 2>&1
    success
}

upgrade_kubeadm() {
  local upg_kube_ver=$1 remote=$2 user_name=$3 node=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd}
  printf "${cyan}Marking kubeadm unhold.... ${reset}"
  ${pre_cmd} sudo apt-mark unhold kubeadm > /dev/null 2>&1
  success
  printf "${cyan}Updating apt.... ${reset}"
  ${pre_cmd} sudo apt update > /dev/dell 2>&1
  success
  printf "${cyan}Upgrading kubeadm to ${upg_kube_ver}.... ${reset}"
  ${pre_cmd} sudo apt install -y kubeadm=${upg_kube_ver}-00
  success
  printf "${cyan}Marking kubeadm hold.... ${reset}"
  ${pre_cmd} sudo apt-mark hold kubeadm > /dev/null 2>&1
  success
}

add_user_sudoers() {
  local user_name=$1 remote=$2 node=$3
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd}
  echo ${pre_cmd}
  printf "${cyan}Adding ${user_name} to the sudoers file.... ${reset}"
  echo "${pre_cmd} echo "${user_name} ALL=(ALL) NOPASSWD: ALL" >> ./myuser"
  ${pre_cmd} echo "${user_name} ALL=(ALL) NOPASSWD: ALL" >> ./myuser
  ${pre_cmd} sudo chown root:root ./myuser
  ${pre_cmd} sudo mv ./myuser /etc/sudoers.d/
  success
}

upgrade_kubernetes_software() {
  local upg_kube_ver=$1 remote=$2 user_name=$3 node=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd}
  printf "${cyan}Cordon and Drain node.... ${reset}"
  kubectl drain ${node} --ignore-daemonsets --delete-local-data --force
  success
  printf "${cyan}Planning kubernetes master cluster to ${upg_kube_ver}.... ${reset}"
  ${pre_cmd} sudo kubeadm upgrade plan > /dev/null 2>&1
  success
  if [[ -z ${remote} ]]
  then
    printf "${cyan}Updating kubernetes master to ${upg_kube_ver}.... ${reset}"
    sudo kubeadm upgrade apply v${upg_kube_ver} > /dev/null 2>&1
    success
  else
    printf "${cyan}Updating kubernetes cluster nodes to ${upg_kube_ver}.... ${reset}"
    ${pre_cmd} sudo kubeadm upgrade node v${upg_kube_ver} > /dev/null 2>&1
    success
  fi
}

upgrade_kubelet() {
  local upg_kube_ver=$1 remote=$2 user_name=$3 node=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd}
  printf "${cyan}Marking unhold kubectl and kubelet.... ${reset}"
  ${pre_cmd} sudo apt-mark unhold kubelet kubectl
  success
  printf "${cyan}Updating apt.... ${reset}"
  ${pre_cmd} sudo apt update
  success
  printf "${cyan}Upgrading kubectl and kubelet to ${upg_kube_ver}.... ${reset}"
  ${pre_cmd} sudo apt install -y kubelet=${upg_kube_ver}-00 kubectl=${upg_kube_ver}-00
  success
  printf "${cyan}Marking hold kubectl and kubelet.... ${reset}"
  ${pre_cmd} sudo apt-mark hold kubelet kubectl
  success
  printf "${cyan}Restarting kubelet service.... ${reset}"
  ${pre_cmd} sudo systemctl restart kubelet
  success
  printf "${cyan}Uncordon node.... ${reset}"
  kubectl uncordon ${node}
  success
}

upgrade_kubernetes() {
  local remote user_name
  local kube_versions=( "1.15.12" "1.16.15" "1.17.12" "1.18.9" )
  printf "${magenta}Enter username (adminuser): ${reset}"
  read -s user_name
  if [[ "$user_name" == "" ]]; then user_name="adminuser"; fi
  printf "${cyan}Begin upgrade of kubernetes.... ${reset}\n"
  local hostname=`hostname`
  local masters=( `kubectl get nodes -o json | jq -r '.items[] | .metadata.labels | select(."node-role.kubernetes.io/master" != null) | ."kubernetes.io/hostname"'` )
  local workers=( `kubectl get nodes -o json | jq -r '.items[] | .metadata.labels | select(."node-role.kubernetes.io/master" == null) | ."kubernetes.io/hostname"'` )
  local all_nodes=( "${masters[@]}" "${workers[@]}" )
  for node in "${all_nodes[@]}"
  do
    [[ ${node} != ${hostname} ]] && remote=1

    add_user_sudoers ${user_name} ${remote} ${node}
  done
  for kv in "${kube_versions[@]}"
  do
    for node in "${all_nodes[@]}"
    do
      [[ ${node} != ${hostname} ]] && remote=1
      upgrade_kubeadm ${kv} ${remote} ${user_name} ${node}
      upgrade_kubernetes_software ${kv} ${remote} ${user_name} ${node}
      upgrade_kubelet ${kv} ${remote} ${user_name} ${node}
    done
  done
  printf "${cyan}Completed upgrade of kubernetes.... ${reset}\n"
}

install_prereqs() {
    printf "${cyan}Kickoff ${BRANCH} pre-req install playbook.... ${reset}"
    success
    if [[ " ${install_tags[@]} " =~ " kubectl " ]]
    then
      upgrade_kubernetes
      install_tags=( "${install_tags[@]/kubectl}" )
    fi
    curl https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/playbook.yml -o /tmp/playbook.yml > /dev/null 2>&1
    ansible-playbook /tmp/playbook.yml --inventory=127.0.0.1, --tags $install_tags
}

cleanup() {
    [ -f /tmp/playbook.yml ] && rm /tmp/playbook.yml > /dev/null 2>&1
}

main() {
    local yum apt ansible
    yum_checks yum
    apt_checks apt
    ansible_checks ansible
    if [ $ansible -ne 0 ]
    then
        [ $yum -eq 0 ] && yum_steps
        [ $apt -eq 0 ] && apt_steps
    fi
    install_prereqs
}

branch='master'
install_tags=$1
[[ $2 ]] && branch=$2
main
cleanup
if [[ " ${install_tags[@]} " =~ " kernel " ]]
then
    exit 0
fi
