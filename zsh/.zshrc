# Minimal zsh configuration for devcontainer workflow
# Most development tools will be provided by devcontainers

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# Essential tools for terminal workflow
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[[ -f ~/.fzf_commands.zsh ]] && source ~/.fzf_commands.zsh

# Add local bin to PATH
export PATH="/Users/lukedanielson/.local/bin:$PATH"

# mise (tool version manager) - replaces asdf
eval "$(mise activate zsh)"

# Optional: Uncomment if you need these
# eval "$(scmpuff init --shell=sh)"  # Git status integration