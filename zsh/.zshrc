[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Envars
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
export PGGSSENCMODE=disable

[[ -f ~/.fzf_commands.zsh ]] && source ~/.fzf_commands.zsh

. /opt/homebrew/opt/asdf/libexec/asdf.sh
eval "$(scmpuff init --shell=sh)"

