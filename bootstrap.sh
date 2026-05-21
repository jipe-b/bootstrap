#!/usr/bin/env bash
set -e

BOLD='\033[1m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

step() { printf "\n${BOLD}▶ $1${RESET}\n"; }
ok()   { printf "${GREEN}✓ $1${RESET}\n"; }
info() { printf "${CYAN}  $1${RESET}\n"; }

# ── 1. Xcode CLI tools ────────────────────────────────────────────────────────
step "Xcode CLI tools"
if xcode-select -p &>/dev/null; then
  ok "Already installed"
else
  xcode-select --install 2>/dev/null || true
  printf "\n${YELLOW}  A dialog has opened — click Install, then come back here.${RESET}\n"
  printf "${YELLOW}  Press Enter when done...${RESET} "
  read -r
  xcode-select -p &>/dev/null || { echo "Xcode CLI tools not found, aborting."; exit 1; }
  ok "Installed"
fi

# ── 2. Homebrew ───────────────────────────────────────────────────────────────
step "Homebrew"
if command -v brew &>/dev/null; then
  ok "Already installed"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  ok "Installed"
fi

# ── 3. Tailscale, age, chezmoi ───────────────────────────────────────────────
# Tailscale: required before chezmoi init (NAS only reachable via Tailscale)
# age: required before chezmoi apply (decrypts SSH keys in the repo)
# chezmoi handles the rest (full Brewfile, dotfiles, packages)
step "age"
if command -v age &>/dev/null; then
  ok "Already installed"
else
  brew install age && ok "Installed"
fi

step "chezmoi"
if command -v chezmoi &>/dev/null; then
  ok "Already installed"
else
  brew install chezmoi && ok "Installed"
fi

step "Tailscale"
if [[ -d /Applications/Tailscale.app ]]; then
  ok "Already installed"
else
  brew install --cask tailscale && ok "Installed"
fi

# ── Next steps ────────────────────────────────────────────────────────────────
printf "\n${BOLD}━━━ Next steps (manual) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

info "1. Connect Tailscale"
echo "      Open Tailscale from Applications and log in."
echo ""

info "2. Copy your age key from the NAS (requires Tailscale up)"
echo "      mkdir -p ~/.config/chezmoi"
echo "      ssh jipe@100.96.122.2 'cat ~/config/chezmoi/key.txt' > ~/.config/chezmoi/key.txt"
echo "      chmod 600 ~/.config/chezmoi/key.txt"
echo "      age-keygen -y ~/.config/chezmoi/key.txt  # copy public key"
echo ""

info "3. Init chezmoi from your NAS repo"
echo "      chezmoi init --apply ssh://jipe@100.96.122.2/volume1/Git/dotfiles.git"
echo ""
