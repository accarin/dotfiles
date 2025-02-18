# Set up zinit
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Add zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::ubuntu
zinit snippet OMZP::command-not-found

# Set up the prompt
autoload -Uz promptinit
promptinit
prompt adam1

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History settings
HISTSIZE=5000
SAVEHIST=$HISTSIZE
HISTFILE=~/.zsh_history
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups

# Aliases
alias ls='ls --color'
alias proxy_on='export HTTP_PROXY=http://localhost:3128; export HTTPS_PROXY=http://localhost:3128; export FTP_PROXY=http://localhost:3128; export ALL_PROXY=http://localhost:3128; export NO_PROXY=localhost,127.0.0.1,::1,192.168.*.*,10.*.*.*,*.aam.services,*.oebb.at,*.railcargo.com'
alias proxy_off='unset HTTP_PROXY; unset HTTPS_PROXY; unset FTP_PROXY; unset ALL_PROXY; unset NO_PROXY'

# Shell Integrations
eval "$(fzf --zsh)" #skip on ubuntu 24.04 as fzf version is too old

# Setup completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
eval "$(dircolors -b)"
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

source /usr/share/nvm/init-nvm.sh

# Add ~/.local/bin to path
# path+=('/home/ubuntu/.local/bin')

# Load environment.d variables
#for file in ~/.config/environment.d/* ; do
#    [ -f "$file" ] && cat "$file" | while read line; do line="${line%\"}" && line=$( echo $line | sed 's/=\"/=/') && export $line; done
#done

# integrate with oh my posh
eval "$(oh-my-posh init zsh --config ${HOME}/.config/oh-my-posh/themes/M365Princess.omp.json)"
