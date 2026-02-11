# Wealthbox Development Container Aliases
# Shortcuts for common Wealthbox development container commands

# Wealthbox shell - interactive shell in container (works in crm-web and sandbox directories)
wsh() {
    # Find project root by walking up to Gemfile
    local dir="$PWD"
    while [[ -n "$dir" && ! -f "$dir/Gemfile" ]]; do
        dir="${dir%/*}"
    done

    if [[ -z "$dir" ]]; then
        echo "Error: Not in a CRM project directory (no Gemfile found)"
        return 1
    fi

    # Check if we're in a sandbox
    local sandbox_root="$HOME/Workspace/wealthbox-sandbox"
    if [[ "$dir" == "$sandbox_root"/sandbox-* ]]; then
        local sandbox_name="${dir#$sandbox_root/sandbox-}"
        "$sandbox_root/sandbox" shell "$sandbox_name" "$@"
    elif [[ -f "$dir/bin/docker/interactive.sh" ]]; then
        (cd "$dir" && bin/docker/interactive.sh "$@")
    else
        echo "Error: Not in a CRM project directory"
        return 1
    fi
}

# Wealthbox vim - nvim in devcontainer
wvim() {
    if [[ ! -f ".devcontainer/devcontainer.json" ]]; then
        echo "❌ Error: Must be in the CRM web project directory (~/Workspace/crm-web)"
        return 1
    fi
    devcontainer exec --workspace-folder . nvim "$@"
}

# Wealthbox rails console - rails console in container (works in crm-web and sandbox directories)
wrc() {
    # Find project root by walking up to Gemfile
    local dir="$PWD"
    while [[ -n "$dir" && ! -f "$dir/Gemfile" ]]; do
        dir="${dir%/*}"
    done

    if [[ -z "$dir" ]]; then
        echo "Error: Not in a CRM project directory (no Gemfile found)"
        return 1
    fi

    local sandbox_root="$HOME/Workspace/wealthbox-sandbox"
    if [[ "$dir" == "$sandbox_root"/sandbox-* ]]; then
        local sandbox_name="${dir#$sandbox_root/sandbox-}"
        "$sandbox_root/sandbox" shell "$sandbox_name" rails c "$@"
    elif [[ -f "$dir/bin/docker/interactive.sh" ]]; then
        (cd "$dir" && bin/docker/interactive.sh rails c "$@")
    else
        echo "Error: Not in a CRM project directory"
        return 1
    fi
}

w-overmind-dev() {
  devcontainer exec --workspace-folder . cat Procfile.dev_frontend Procfile.dev_background <(echo "server: bin/dev_server") | overmind start -f /dev/stdin
}


refresh_devcontainer() {
 devcontainer up --workspace-folder . --remove-existing-container
}

# Claude with Wealthbox plugin (local development)
alias claude-wb='claude --plugin-dir ~/Workspace/wealthbox-claude-plugin/plugins/wealthbox'
