#!/usr/bin/env bash
#
# Dotfiles installer - Homebrew-first approach for macOS and Linux
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${DOTFILES_DIR}/install.log"
CHANGE_SHELL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --no-shell-change)
      CHANGE_SHELL=false
      shift
      ;;
    -h|--help)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --no-shell-change  Skip changing default shell to zsh"
      echo "  -h, --help         Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Logging helpers
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$msg" | tee -a "$LOG_FILE"
}

log_error() {
  log "ERROR: $*" >&2
}

die() {
  log_error "$*"
  exit 1
}

# Pre-flight checks
preflight_checks() {
  log "Running pre-flight checks..."

  # Check OS
  case "$(uname -s)" in
    Darwin)
      OS="macos"
      ;;
    Linux)
      OS="linux"
      ;;
    *)
      die "Unsupported operating system: $(uname -s)"
      ;;
  esac
  log "Detected OS: $OS"

  # Check internet connectivity
  if ! curl -sfI https://github.com >/dev/null 2>&1; then
    die "No internet connection. Please check your network."
  fi
  log "Internet connectivity: OK"

  # Check git
  if ! command -v git &>/dev/null; then
    die "git is required but not installed"
  fi
  log "git: OK"
}

# Install Homebrew if not present
install_homebrew() {
  if command -v brew &>/dev/null; then
    log "Homebrew already installed"
    return 0
  fi

  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH for this session
  if [[ "$OS" == "linux" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ "$OS" == "macos" && "$(uname -m)" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  log "Homebrew installed successfully"
}

# Install packages via Homebrew
install_packages() {
  log "Installing packages via Homebrew..."

  # On Linux, ensure build dependencies are available for Homebrew
  if [[ "$OS" == "linux" ]]; then
    if command -v apt-get &>/dev/null; then
      log "Installing Homebrew build dependencies via apt..."
      sudo apt-get update
      sudo apt-get install -y build-essential procps curl file git
    elif command -v dnf &>/dev/null; then
      log "Installing Homebrew build dependencies via dnf..."
      sudo dnf groupinstall -y 'Development Tools'
      sudo dnf install -y procps-ng curl file git
    elif command -v pacman &>/dev/null; then
      log "Installing Homebrew build dependencies via pacman..."
      sudo pacman -Sy --noconfirm base-devel procps-ng curl file git
    fi
  fi

  brew bundle install --file="${DOTFILES_DIR}/brew/Brewfile"
  log "Packages installed successfully"
}

# Initialize git submodules
init_submodules() {
  log "Initializing git submodules..."
  git -C "$DOTFILES_DIR" submodule update --init --recursive
  log "Git submodules initialized"
}

# Link dotfiles using stow
link_dotfiles() {
  log "Unlinking old dotfiles..."
  "$DOTFILES_DIR/link.sh" unlink || true

  log "Linking dotfiles..."
  "$DOTFILES_DIR/link.sh" link
  log "Dotfiles linked successfully"
}

# Change default shell to zsh
change_shell() {
  if [[ "$CHANGE_SHELL" != true ]]; then
    log "Skipping shell change (--no-shell-change specified)"
    return 0
  fi

  if [[ "$SHELL" == *"zsh"* ]]; then
    log "zsh is already the default shell"
    return 0
  fi

  local zsh_path
  zsh_path="$(which zsh)"

  # Ensure zsh is in /etc/shells
  if ! grep -q "^${zsh_path}$" /etc/shells 2>/dev/null; then
    log "Adding $zsh_path to /etc/shells..."
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi

  log "Changing default shell to zsh..."
  log "NOTE: This may prompt for your password"
  if chsh -s "$zsh_path"; then
    log "Default shell changed to zsh"
  else
    log "WARNING: Could not change shell. Run manually: chsh -s $zsh_path"
  fi
}

# Verify installation
verify_installation() {
  log "Verifying installation..."
  local failed=0

  # Check critical commands
  for cmd in nvim tmux fzf rg mise zsh git; do
    if command -v "$cmd" &>/dev/null; then
      log "  $cmd: OK"
    else
      log_error "  $cmd: MISSING"
      failed=1
    fi
  done

  # Check optional but expected commands
  for cmd in jq aws scmpuff lazygit; do
    if command -v "$cmd" &>/dev/null; then
      log "  $cmd: OK"
    else
      log "  $cmd: not found (optional)"
    fi
  done

  if [[ $failed -eq 1 ]]; then
    log "WARNING: Some critical tools are missing. Check the log above."
    return 1
  fi

  log "Installation verified successfully!"
  return 0
}

# Main installation flow
main() {
  echo "" > "$LOG_FILE"  # Reset log file
  log "Starting dotfiles installation..."
  log "Log file: $LOG_FILE"

  preflight_checks
  install_homebrew
  init_submodules
  install_packages
  link_dotfiles
  change_shell
  verify_installation

  log ""
  log "============================================"
  log "Dotfiles installation complete!"
  log "============================================"
  log ""
  log "Next steps:"
  log "  1. Start a new terminal session (or run: exec zsh)"
  log "  2. Run 'mise install' to install language runtimes"
  log ""
  log "Full log available at: $LOG_FILE"
}

main
