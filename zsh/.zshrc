# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# Homebrew setup (Linux)
if [[ -f /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# Homebrew setup (macOS Apple Silicon)
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# mise (tool version manager) - replaces asdf
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# fzf - fuzzy finder
if command -v fzf &>/dev/null; then
  source <(fzf --zsh)
  [[ -f ~/.fzf_commands.zsh ]] && source ~/.fzf_commands.zsh
fi

# scmpuff - git status number shortcuts
if command -v scmpuff &>/dev/null; then
  eval "$(scmpuff init --shell=sh)"
fi

# Wealthbox development aliases
[[ -f ~/.wealthbox_aliases.zsh ]] && source ~/.wealthbox_aliases.zsh

# === AWS Profile Aliases ===
# Requires: jq, awscli, coreutils (for gdate on macOS)
if command -v aws &>/dev/null && command -v jq &>/dev/null; then
  _aws-set-profile(){
    local sso_session expires
    echo "activating aws profile: $1" >&2
    export AWS_PROFILE="$1"
    export AWS_DEFAULT_REGION="us-east-1"
    sso_session="$(aws configure get sso_session 2>/dev/null)"
    if [[ -n "$sso_session" ]]; then
      expires=$(aws configure export-credentials | jq -r '.Expiration')
      # Use gdate on macOS (from coreutils), date on Linux
      local date_cmd="date"
      if [[ "$(uname)" == "Darwin" ]]; then
        if command -v gdate &>/dev/null; then
          date_cmd="gdate"
        else
          echo "WARNING: gdate not found. Install coreutils: brew install coreutils" >&2
          return 1
        fi
      fi
      if [[ -z "$expires" || $($date_cmd --date "$expires" +'%s') -lt $($date_cmd --date "+2 hours" +'%s') ]]; then
       echo "refreshing sso session" >&2
       aws sso login --sso-session "$sso_session"
      fi
    fi
  }
  if [[ -f "${AWS_CONFIG_FILE:-$HOME/.aws/config}" ]]; then
    for p in $(cat ${AWS_CONFIG_FILE:-~/.aws/config} | grep -E '^[[:space:]]*\[profile' | awk '{print substr($2, 1, length($2)-1)}'); do
      [[ "$p" == "default" ]] && continue
      eval "awsp-$p(){ _aws-set-profile \"$p\" }"
    done
  fi
fi
# === End AWS Profile Aliases ===

# SSH aliases
alias prod='ssh -t production "TERM=xterm-256color tmux attach || tmux new"'
