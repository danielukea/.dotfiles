# Wealthbox Development Container Aliases
# Shortcuts for common Wealthbox development container commands

# Wealthbox shell - interactive shell in container
wsh() {
    if [[ ! -f "bin/docker/interactive.sh" ]]; then
        echo "❌ Error: Must be in the CRM web project directory (~/Workspace/crm-web)"
        return 1
    fi
    bin/docker/interactive.sh "$@"
}

# Wealthbox vim - nvim in devcontainer
wvim() {
    if [[ ! -f ".devcontainer/devcontainer.json" ]]; then
        echo "❌ Error: Must be in the CRM web project directory (~/Workspace/crm-web)"
        return 1
    fi
    devcontainer exec --workspace-folder . nvim "$@"
}

# Wealthbox rails console - rails console in container
wrc() {
    if [[ ! -f "bin/docker/interactive.sh" ]]; then
        echo "❌ Error: Must be in the CRM web project directory (~/Workspace/crm-web)"
        return 1
    fi
    bin/docker/interactive.sh rails c "$@"
}
