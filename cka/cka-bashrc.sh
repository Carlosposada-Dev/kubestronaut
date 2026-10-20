# ---- CKA ---- append to ~/.bashrc on cp1 ONLY (plan.md §8.2 — never the host), then: source ~/.bashrc
# Superseded by cka-D1.md §0 / §0.4 if they differ.
alias k=kubectl
complete -o default -F __start_kubectl k
export do="--dry-run=client -o yaml"
export now="--force --grace-period=0"
alias kn='kubectl config set-context --current --namespace'
alias kgp='kubectl get pods -o wide'
alias kga='kubectl get all -A'
alias kd='kubectl describe'
alias kx='kubectl explain --recursive'
export KUBE_EDITOR=vim
export ETCDCTL_API=3
# ---- end CKA ----
# ~/.vimrc:
#   set ts=2 sw=2 et ai nu
#   syntax on
# Verify:  type k && alias | grep -c kubectl && k run t --image=nginx $do | head -3 && rm -f ~/.vimrc.bak
