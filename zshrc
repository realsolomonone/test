# Fig pre block. Keep at the top of this file.
[[ -f "$HOME/.fig/shell/zshrc.pre.zsh" ]] && builtin source "$HOME/.fig/shell/zshrc.pre.zsh"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

#gem

#fzf
#[ -f /.fzf.zsh ] && source /.fzf.zsh

# FZF settings
export FZF_BASE="$HOME/.fzf"
export FZF_DEFAULT_COMMAND='rg --hidden --no-ignore --files -g "!.git/"'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# aliases
alias gs="git status"
alias ls="ls -lrta" 
alias rm-tf-state='fig run rm-tf-state'
alias rm-ssh='fig run ssh'
alias gitpush='fig run gitpush'

#kubernetes
PS1='$(kube_ps1)'$PS1
source <(kubectl completion zsh)
[ -f /.kubectl_aliases ] && source /.kubectl_aliases
[ -f ~/.kubectl_aliases ] && source \
   <(cat ~/.kubectl_aliases | sed -r 's/(kubectl.*) --watch/watch \1/g')
function kubectl() { echo "+ kubectl $@">&2; command kubectl $@; }

#ruby
export LDFLAGS="-L/opt/homebrew/opt/ruby/lib"
export CPPFLAGS="-I/opt/homebrew/opt/ruby/include"
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
# Fig post block. Keep at the bottom of this file.

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"


# source <(kubeone completion bash)

PROMPT='%(?.%F{blue}√.%F{red}?%?)%f %F{red}%1~ @mac %f%(?.%F{green}✪—➤ '
alias l='ls -lrt'
alias ll='ls -lrt'
alias la='ls -lrta --color'
alias df='df -hP'
alias su='sudo su -'
alias dir='ls -l | grep '^d''

alias dev-box='ssh -i ~/.ssh/hasp-platform-aws-pem01.pem ubuntu@52.73.81.155'
# User specific aliases and functions
alias start-all='/mnt/c/staging/aws/ansible-aws-ec2-playbook/ec2-start-all-instances.yml'
alias stop-all='/mnt/c/staging/aws/ansible-aws-ec2-playbook/ec2-stop-all-instances.yml'
alias terminate-all='/mnt/c/staging/aws/ansible-aws-ec2-playbook/ec2-terminate-all-instances.yml'
alias ms='~/scripts/list-instance.sh'
alias ms2='~/scripts/2list-instance.sh'
alias alls='/mnt/c/staging/aws/aws-scripts/list-all-instance.sh'
alias ec2='/mnt/c/staging/aws/aws-scripts/list-all-instance.sh'
alias scripts='/mnt/c/staging/aws/aws-scripts'
alias launch-1='/mnt/c/staging/aws/ansible-aws-ec2-playbook/1_ec2-provision.yml'
alias launch-more='/mnt/c/staging/aws/ansible-aws-ec2-playbook/1_ec2-deploy-multiple-instances.yml'
alias validate='terraform validate'
alias fmt='terraform fmt'
alias plan='terraform plan'
alias destroy='terraform destroy --auto-approve'
alias apply='terraform apply --auto-approve'
alias hub='cd /mnt/c/GitHub'
alias learn-ansible='/mnt/c/staging/aws/learn-ansible-aws'
alias learn-tf='/mnt/c/staging/aws/learn-terraform-aws'
alias ansible-pro='/mnt/c/staging/aws/Ansible-Project'
alias elb='/mnt/c/staging/aws/Ansible-Project/ansible-elb-playbook'
alias github='cd /mnt/c/GitHub'
alias ansible-jenkins='cd /mnt/c/GitHub/ansible-jenkins'
alias terraform-jenkins='cd /mnt/c/GitHub/terraform-jenkins'
alias dc='/mnt/c/GitHub/TERRAFORM-PROJECT-2022'
alias glab='/mnt/c/GitHub/TERRAFORM/GITLAB-HELM-PROJECT'
alias ansible-ec2='cd /mnt/c/staging/aws/Ansible-Project/ansible-ec2-playbook'
alias change='ansible-playbook --ask-vault-pass /mnt/c/staging/aws/Ansible-Project/ansible-ec2-playbook/1_ec2-change-state.yml -i /mnt/c/staging/aws/Ansible-Project/ansible-ec2-playbook/hosts'
alias devboxu='ssh -i ~/helm-test.pem ubuntu@3.16.49.47'
alias devbox8='ssh -i ~/helm-test.pem ec2-user@3.136.198.17'
alias devb='ssh ec2-user@3.146.184.86'
alias dw='ssh -i ~/helm-test.pem ec2-user@3.136.198.17'
alias ms='/Users/swilliams/scripts/ms-instance.sh'
alias init='terraform init'
alias apply='terraform apply -auto-approve'
alias destroy='terraform destroy -auto-approve'


alias node='kubectl get nodes'
#source ~/env/bin/activate


# if [[ -n $SSH _CONNECTION ]] ; then
#     source ~/env/bin/activate
# fi 
#
alias kconfig='kubectl config get-contexts'
alias guni='helm uninstall gitlab -n gitlab'
alias elb='kubectl --namespace ingress-nginx  get services -o wide -w nginx-ingress-ingress-nginx-controller'
alias ks='kubectl get services'
alias gw='kubectl get pods --namespace=gitlab --watch'
alias hil='helm install longhorn longhorn/longhorn --namespace longhorn-system --create-namespace'
alias kll='kubectl -n longhorn-system get pod'
alias hdl='helm uninstall longhorn --namespace longhorn-system'
alias wl='helm search repo longhorn'
alias k='kubectl'
alias kgp='kubectl describe po'
alias kns='kubectl get ns'
alias kpl='kubectl logs'
alias kgn='kubectl get nodes'
alias kinfo='kubectl cluster-info'
alias kgd='kubectl cluster-info dump'
alias kcn='kubectl create ns'
alias kdt='kubectl delete ns'
alias kc="kubectl create -f"
alias kds="kubectl describe svc"
alias kgit='kubectl get pods --namespace=gitlab'
alias ngl='kubectl get svc --namespace=ingress-nginx'
alias alln='helm list --all-namespaces'
alias ing='k get ing -A'
alias ielb='kubectl get svc --namespace=ingress-nginx'
alias glab='k get pod -n gitlab -w'

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /usr/bin/terraform terraform
export PATH=$PATH:$HOME/bin

alias n='kubectl get ns'
alias p='kubectl get pod'
alias s='kubectl get svc'
alias all='kubectl get pods --all-namespaces'
alias dp='kubectl get deployment'
alias stor='kubectl get storageclass'

alias codebase='cd /Users/swilliams/Documents/CODEBASE'
alias desktop='cd /Users/swilliams/Desktop'
# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

alias meta-ips='k get svc --all-namespaces --no-headers | awk '{print $5}' | grep -v none'
alias see-all='kubectl get deployments,services,pods -n'

### Switching Between Contexts
alias get-clusters='kubectl config get-clusters'
alias get-users='kubectl config get-users'
alias get-current='kubectl config current-context'
alias use-context='kubectl config use-context'
alias get-contexts='kubectl config get-contexts'

### delete
alias delete-all='kubectl delete daemonsets,replicasets,services,deployments,pods,rc,ingress --all -n'
alias all='kubectl get pods --no-headers=true --all-namespaces'

# kubectx
# kubens 

#PROMPT='$(kube_ps1)'$PROMPT
function get_namespace_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

export KUBE_PS1_NAMESPACE_FUNCTION=get_namespace_upper

export KUBECTX_CURRENT_FGCOLOR=$(tput setaf 6) # blue text
export KUBECTX_CURRENT_BGCOLOR=$(tput setab 7) # white background

### alias update-context="'KUBECONFIG=$(find ~/.kube/clusters -type f | sed ':a;N;s/\n/:/;ba') kubectl config view --flatten > ~/.kube/config'"
#
alias tfip='terraform init && terraform fmt && terraform validate && terraform plan'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='time terraform fmt && terraform validate && terraform apply -auto-approve'
alias tfd='terraform destroy -auto-approve'

# govc find / -type f
# govc find / -type s
# govc find / -type p

alias vms='govc ls /DEV-DC/vm'
alias arg='cp ~/.kube/clusters/argo.config ~/.kube/config && kns && node'

#go run main.go
#go run main.go –url https://vcenter.kendopz.com\\api:Soly2020!123@@solomon@vsphere.local/sdk –insecure true


alias tcleanup='rm -rf .terraform .terraform.lock.hcl  terraform.tfstate.backup terraform.tfstate && rm -rf .terraform.tfstate.lock.info'


#// vmpath=$(govc vm.info test-1.kendopz.com | grep "Path:" | awk {'print $2'})
#// govc ls -l -json $vmpath

#govc vm.power -r=true test-1.kendopz.com

complete -F __start_velero v

alias tcleanup='rm -rf .terraform .terraform.lock.hcl  terraform.tfstate.backup terraform.tfstate'
alias list-eks='eksctl get cluster'

### Update context 
## alias update-context="'KUBECONFIG=$(find ~/.kube/clusters -type f | sed ':a;N;s/\n/:/;ba') kubectl config view --flatten > ~/.kube/config'"

####
[ -f ~/.kubectl_aliases ] && source \
   <(cat ~/.kubectl_aliases | sed -r 's/(kubectl.*) --watch/watch \1/g')

##### Vault 

alias vault-po='kubectl get po -n vault'

### How To Get All The Domain Records For Your Account From Route53
###alias aws-53='aws route53 list-hosted-zones|jq '.[] | .[] | .Id' | sed 's!/hostedzone/!!' | sed 's/"//g'> zones'

### AMI finder
alias ami-finder='bash /Users/swilliams/scripts/ami.sh'

### Update EKS
alias update-eks='aws eks update-kubeconfig'

### Delete EKS 
alias delete-elb='aws elb delete-load-balancer --load-balancer-name' 

### List ELB 
alias list-elb='aws elb describe-load-balancers --query LoadBalancerDescriptions[*].LoadBalancerName'


alias list-keys='aws iam list-access-keys --user-name developer'
alias list-kms='aws kms list-keys'
alias keypair='aws ec2 describe-key-pairs'
alias list-route53='aws route53 list-hosted-zones'


####### Install Jira 

alias install-jira='~/scripts/jira-install.sh'
alias uninstall-jira='~/scripts/jira-uninstall.sh'

### Install EKS
alias deploy-eks='~/eks/deploy-eks.sh'
alias act='source aws-ansible-env/bin/activate'
source <(kubectl completion zsh)

# === Enable Zsh Completion System ===
autoload -Uz compinit
compinit

# Enable bash-style completion (needed for terraform, aws, etc.)
autoload -U +X bashcompinit && bashcompinit

# === kubectl Completion ===
if command -v kubectl &>/dev/null; then
  source <(kubectl completion zsh)
fi

# === terraform Completion ===
if command -v terraform &>/dev/null; then
  complete -o nospace -C /usr/bin/terraform terraform
fi

# === aws CLI Completion ===
if command -v aws_completer &>/dev/null; then
  complete -C aws_completer aws
fi

# === fzf Completion ===
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# === Optional: Git Completion (if installed manually)
if [ -f /usr/share/zsh/site-functions/_git ]; then
  fpath=(/usr/share/zsh/site-functions $fpath)
fi

# === Helpful Bindings (Tab & Shift+Tab) ===
bindkey '^I' menu-complete
bindkey '^[[Z' reverse-menu-complete
export VAULT_ADDR=http://127.0.0.1:8200
