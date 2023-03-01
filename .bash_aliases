alias aliases="vim ~/.bash_aliases && source ~/.zshrc"

# --- Git ---
alias gco="git checkout"
alias gcm="git commit -a -m"
alias gpoh="git push -u origin head"

# --- Workflow ---
alias pnrd="git pull && npm run dev"
alias vnrd="git pull && npm i && npm run dev"
alias nrd="npm i && npm run dev"
alias nrds="npm run dev:start"
alias grep='grep --color=auto'

# --- VS Code ---
alias c='code .'

# --- MacOS ---
alias finder='open'
alias whiptail="dialog"
alias c='clear'

# --- Navigation ---
alias ll='ls -alF'
alias ldir="ls -al | grep ^d"
alias ..='cd ..'
alias ...='cd ../..'
alias h='history'
alias c='clear'
alias md='mkdir -p'
alias duh='du -sh * | sort -hr'
alias unzip='tar -zxvf'

# --- Kubernetes ---
alias kc=“kubectl”
