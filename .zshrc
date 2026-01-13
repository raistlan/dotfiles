export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

[ -f ~/.zsh_aliases ] && source ~/.zsh_aliases

# =============================
# Added via mac_setup.sh:

# Apple Silicon-friendly Node version manager
eval "$(fnm env --use-on-cd --version-file-strategy recursive)"

# This loads zsh completions for Brew packages
# https://docs.brew.sh/Shell-Completion
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
autoload -Uz compinit
compinit

export PYCURL_SSL_LIBRARY=openssl
export LDFLAGS="-L$(brew --prefix)/opt/openssl/lib"
export CPPFLAGS="-I/$(brew --prefix)/opt/openssl/include"

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PIPENV_PYTHON="$PYENV_ROOT/shims/python"

plugin=(
  pyenv
)

eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# =============================
alias python=python3
