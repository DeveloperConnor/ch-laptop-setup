# Enable Powerlevel10k instant prompt.
# Keep this close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#
# Linuxbrew and PATH
#

if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Add user-local executable directories.
typeset -U path PATH

path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  $path
)

export PATH

#
# Oh My Zsh
#

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(
  git
)

source "$ZSH/oh-my-zsh.sh"

#
# Convenience aliases
#

alias ll="ls -alF"
alias la="ls -A"
alias l="ls -CF"

#
# Terraform aliases
#

alias tf="terraform"
alias tfp="terraform plan"
alias tfa="terraform apply"
alias tfd="terraform destroy"
alias tfi="terraform init"

#
# Git aliases
#

alias ga="git add"
alias gp="git push"

#
# AWS defaults
#

export AWS_PROFILE="${AWS_PROFILE:-platform-sandbox}"
export AWS_REGION="${AWS_REGION:-eu-west-2}"
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-$AWS_REGION}"

#
# NVM
#

export NVM_DIR="$HOME/.nvm"

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
fi

#
# SSH agent
#
# Reuse an agent provided by VS Code Remote SSH when available.
# Otherwise start and persist an agent on the VDE.
#

SSH_ENV="$HOME/.ssh/agent_pid.env"

start_ssh_agent() {
  mkdir -p "$HOME/.ssh"

  ssh-agent -s > "$SSH_ENV"
  chmod 600 "$SSH_ENV"
  source "$SSH_ENV" >/dev/null

  if [[ -f "$HOME/.ssh/github" ]]; then
    ssh-add "$HOME/.ssh/github"
  fi
}

# Do not replace an agent forwarded or supplied by VS Code.
if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
  if [[ -f "$SSH_ENV" ]]; then
    source "$SSH_ENV" >/dev/null

    if [[ -z "${SSH_AGENT_PID:-}" ]] ||
       ! kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
      start_ssh_agent
    fi
  else
    start_ssh_agent
  fi
fi

#
# Zsh autosuggestions
#

if [[ -r "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

#
# Powerlevel10k configuration
#

[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"