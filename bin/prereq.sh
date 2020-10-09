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

function version { echo "$@" | awk -F. '{ printf("%03d%03d%03d\n",
                                        $1,$2,$3); }'; }

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
  local upg_kube_ver=$1 user_name=$2 node=$3 remote=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd} || pre_cmd=""
  local curr_adm_ver=`${pre_cmd} kubeadm version -o short | awk '{print substr($1,2);}'`
  [ $(version ${curr_adm_ver}) -ge $(version ${upg_kube_ver}) ] && return 0
  printf "${cyan}Marking kubeadm unhold.... ${reset}"
  ${pre_cmd} sudo apt-mark unhold kubeadm > /dev/null 2>&1
  success
  printf "${cyan}Updating apt.... ${reset}"
  ${pre_cmd} sudo apt update > /dev/null 2>&1
  success
  printf "${cyan}Upgrading kubeadm to ${upg_kube_ver}.... ${reset}"
  ${pre_cmd} sudo apt install -y kubeadm=${upg_kube_ver}-00 > /dev/null 2>&1
  success
  printf "${cyan}Marking kubeadm hold.... ${reset}"
  ${pre_cmd} sudo apt-mark hold kubeadm > /dev/null 2>&1
  success
}

add_user_sudoers() {
  local user_name=$1 node=$2 remote=$3
  local ssh_cmd="ssh -t ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd} || pre_cmd=""
  printf "${cyan}Adding ${user_name} to the sudoers file.... ${reset}"
  if [[ -z ${remote} ]]
  then
    echo "${user_name} ALL=(ALL:ALL) NOPASSWD:ALL" > ./myuser
  else
    ${pre_cmd} "echo \"${user_name} ALL=(ALL:ALL) NOPASSWD:ALL\" > ./myuser"
  fi
  ${pre_cmd} sudo chown root:root ./myuser
  ${pre_cmd} sudo mv ./myuser /etc/sudoers.d/
  success
}

upgrade_kubernetes_software() {
  local upg_kube_ver=$1 user_name=$2 node=$3 remote=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd} || pre_cmd=""
  printf "${cyan}Cordon and Drain node.... ${reset}"
  kubectl drain ${node} --ignore-daemonsets --delete-local-data --force > /dev/null 2>&1
  success
  if [[ -z ${remote} ]]
  then
    printf "${cyan}Planning kubernetes master cluster to ${upg_kube_ver}.... ${reset}"
    ${pre_cmd} sudo kubeadm upgrade plan > /dev/null 2>&1
    success
    printf "${cyan}Updating kubernetes master to ${upg_kube_ver}.... ${reset}"
    echo "y" | sudo kubeadm upgrade apply v${upg_kube_ver} > /dev/null 2>&1
    success
    printf "${cyan}Updating flannel.... ${reset}"
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml > /dev/null 2>&1
    success
  else
    printf "${cyan}Updating kubernetes cluster nodes to ${upg_kube_ver}.... ${reset}"
    output=`echo "y" | ${pre_cmd} sudo kubeadm upgrade node`
    success
  fi
}

upgrade_kubelet() {
  local upg_kube_ver=$1 user_name=$2 node=$3 remote=$4
  local ssh_cmd="ssh ${user_name}@${node}"
  [[ ! -z "$remote" ]] && pre_cmd=${ssh_cmd} || pre_cmd=""
  local curr_ctl_ver=`${pre_cmd} kubectl version --short | awk 'NR==1 {print substr($3,2);}'`
  local curr_let_ver=`${pre_cmd} kubelet --version | awk '{print substr($2,2);}'`
  printf "${cyan}Marking unhold kubectl and kubelet.... ${reset}"
  ${pre_cmd} sudo apt-mark unhold kubelet kubectl > /dev/null 2>&1
  success
  printf "${cyan}Updating apt.... ${reset}"
  ${pre_cmd} sudo apt update > /dev/null 2>&1
  success
  if [ $(version ${curr_ctl_ver}) -lt $(version ${upg_kube_ver}) ]
  then
    printf "${cyan}Upgrading kubectl to ${upg_kube_ver}.... ${reset}"
    ${pre_cmd} sudo apt install -y kubectl=${upg_kube_ver}-00 > /dev/null 2>&1
    success
  fi
  if [ $(version ${curr_let_ver}) -lt $(version ${upg_kube_ver}) ]
  then
    printf "${cyan}Upgrading kubelet to ${upg_kube_ver}.... ${reset}"
    ${pre_cmd} sudo apt install -y kubelet=${upg_kube_ver}-00 > /dev/null 2>&1
    success
  fi
  printf "${cyan}Restarting kubelet service.... ${reset}"
  ${pre_cmd} sudo systemctl restart kubelet > /dev/null 2>&1
  success
  printf "${cyan}Marking hold kubectl and kubelet.... ${reset}"
  ${pre_cmd} sudo apt-mark hold kubelet kubectl > /dev/null 2>&1
  success
  printf "${cyan}Uncordon node.... ${reset}"
  kubectl uncordon ${node} > /dev/null 2>&1
  success
}

upgrade_kubernetes() {
  local remote user_name="adminuser"
  local kube_versions=( "1.15.12" "1.16.15" "1.17.12" "1.18.9" )
  printf "${cyan}Begin upgrade of kubernetes.... ${reset}\n"
  ssh-keygen
  local hostname=`hostname`
  local masters=( `kubectl get nodes -o json | jq -r '.items[] | .metadata.labels | select(."node-role.kubernetes.io/master" != null) | ."kubernetes.io/hostname"'` )
  local workers=( `kubectl get nodes -o json | jq -r '.items[] | .metadata.labels | select(."node-role.kubernetes.io/master" == null) | ."kubernetes.io/hostname"'` )
  local all_nodes=( "${masters[@]}" "${workers[@]}" )
  for node in "${all_nodes[@]}"
  do
    [[ ${node} != ${hostname} ]] && remote=1 && echo "Password123!" | ssh-copy-id ${user_name}@${node}
    add_user_sudoers ${user_name} ${node} ${remote}
    remote=""
  done
  for kv in "${kube_versions[@]}"
  do
    for new_node in "${all_nodes[@]}"
    do
      [[ ${new_node} != ${hostname} ]] && remote=1
      upgrade_kubeadm ${kv} ${user_name} ${new_node} ${remote}
      upgrade_kubernetes_software ${kv} ${user_name} ${new_node} ${remote}
      upgrade_kubelet ${kv} ${user_name} ${new_node} ${remote}
      remote=""
    done
  done
  printf "${cyan}Completed upgrade of kubernetes.... ${reset}\n"
  kubectl version --short
}

install_prereqs() {
    printf "${cyan}Kickoff ${BRANCH} pre-req install playbook.... ${reset}"
    success
    curl https://raw.githubusercontent.com/EMC-Underground/project_colfax/${BRANCH}/playbook.yml -o /tmp/playbook.yml > /dev/null 2>&1
    ansible-playbook /tmp/playbook.yml --inventory=127.0.0.1, --tags $install_tags
    if [[ " ${install_tags[@]} " =~ " kubectl " ]]
    then
      upgrade_kubernetes
      install_tags=( "${install_tags[@]/kubectl}" )
    fi
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
