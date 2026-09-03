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

# ── Next steps: Netbird + age key (shared by both OSes) ────────────────────
next_steps_common() {
  printf "\n${BOLD}━━━ Next steps (manual) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n\n"

  info "1. Connect Netbird"
  echo "      A brand-new device can't use interactive browser login (/oauth2"
  echo "      is mesh-only, unreachable before you're connected) — use a setup"
  echo "      key instead, generated from an already-connected device:"
  echo "      https://netbird.jipe-homelab.fr → Setup Keys"
  echo "      netbird up --setup-key <KEY>"
  echo ""

  info "2. Copy your age key"
  echo "      mkdir -p ~/.config/chezmoi"
  echo "      ssh <user>@<nas-ip> 'cat ~/config/chezmoi/key.txt' > ~/.config/chezmoi/key.txt"
  echo "      chmod 600 ~/.config/chezmoi/key.txt"
  echo "      age-keygen -y ~/.config/chezmoi/key.txt  # copy public key"
  echo ""
}

# ── Next steps: macOS ────────────────────────────────────────────────────────
next_steps() {
  next_steps_common

  info "3. Init chezmoi"
  echo "      chezmoi init --apply <repo-url>"
  echo "      Profile prompt → work / server / perso, whichever fits this machine"
  echo ""
}

# ── Next steps: Linux ────────────────────────────────────────────────────────
# dotfiles' Forgejo key is chezmoi-managed and shared across machines -- can't
# be used for this very first clone. This script already generated a
# device-dedicated key above; register its public half manually, then use it
# for a one-time clone via GIT_SSH_COMMAND (never needs a permanent SSH config
# entry -- chezmoi's own dot_ssh/config.tmpl takes over after apply).
linux_next_steps() {
  local forgejo_key="$1"

  next_steps_common

  info "3. Register this device's Forgejo SSH key"
  echo "      https://forge.int.jipe-homelab.fr → Settings → SSH/GPG Keys → Add Key"
  echo "      Paste the contents of: ${forgejo_key}.pub"
  echo ""

  info "4. Init chezmoi"
  echo "      GIT_SSH_COMMAND=\"ssh -i ${forgejo_key} -o IdentitiesOnly=yes\" \\"
  echo "        chezmoi init --apply ssh://git@forge.int.jipe-homelab.fr:222/0xJipe/dotfiles.git"
  echo "      Profile prompt → perso"
  echo ""
}

if [[ "$(uname)" == "Darwin" ]]; then
  # ── 1. Xcode CLI tools ──────────────────────────────────────────────────────
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

  # ── 2. Homebrew ─────────────────────────────────────────────────────────────
  step "Homebrew"
  if command -v brew &>/dev/null; then
    ok "Already installed"
  else
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    ok "Installed"
  fi

  # ── 3. Core tools ───────────────────────────────────────────────────────────
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

  step "Netbird"
  if brew list --cask netbirdio/tap/netbird-ui &>/dev/null; then
    ok "Already installed"
  else
    brew install --cask netbirdio/tap/netbird-ui && ok "Installed"
  fi

  next_steps

elif [[ "$(uname)" == "Linux" ]]; then
  if command -v pacman &>/dev/null; then
    # ── Arch/CachyOS ────────────────────────────────────────────────────────
    step "age"
    if command -v age &>/dev/null; then
      ok "Already installed"
    else
      sudo pacman -S --needed --noconfirm age && ok "Installed"
    fi

    step "chezmoi"
    if command -v chezmoi &>/dev/null; then
      ok "Already installed"
    else
      # Confirmed live (2026-09-03): chezmoi is a static Go binary, not
      # rebuilt into cachyos-extra-v3 (that repo only mirrors packages that
      # actually benefit from x86-64-v3 compiler flags) -- plain `extra`
      # resolves cleanly here, no provider clash for this specific package.
      sudo pacman -S --needed --noconfirm chezmoi && ok "Installed"
    fi

    step "yay (AUR helper)"
    if command -v yay &>/dev/null; then
      ok "Already installed"
    else
      sudo pacman -S --needed --noconfirm base-devel git
      tmpdir="$(mktemp -d)"
      git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
      (cd "$tmpdir/yay" && makepkg -si --noconfirm)
      rm -rf "$tmpdir"
      ok "Installed"
    fi

    step "Netbird"
    if command -v netbird-ui &>/dev/null; then
      ok "Already installed"
    else
      yay -S --needed --noconfirm netbird netbird-ui && ok "Installed"
    fi

  elif command -v apt-get &>/dev/null; then
    # ── Debian/Ubuntu ───────────────────────────────────────────────────────
    step "age"
    if command -v age &>/dev/null; then
      ok "Already installed"
    else
      sudo apt-get update && sudo apt-get install -y age && ok "Installed"
    fi

    step "chezmoi"
    if command -v chezmoi &>/dev/null; then
      ok "Already installed"
    else
      # Debian has no chezmoi apt package -- official install script instead.
      # It installs to ./bin by default (relative to CWD, not on PATH), so
      # install to a scratch dir first and move the binary somewhere
      # predictable rather than relying on wherever this script was run from.
      tmpdir="$(mktemp -d)"
      sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$tmpdir"
      sudo mv "$tmpdir/chezmoi" /usr/local/bin/chezmoi
      rm -rf "$tmpdir"
      ok "Installed"
    fi

    step "Netbird"
    if command -v netbird-ui &>/dev/null; then
      ok "Already installed"
    else
      sudo apt-get install -y ca-certificates curl gnupg
      curl -sSL https://pkgs.netbird.io/debian/public.key | \
        sudo gpg --dearmor --output /usr/share/keyrings/netbird-archive-keyring.gpg
      echo 'deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] https://pkgs.netbird.io/debian stable main' | \
        sudo tee /etc/apt/sources.list.d/netbird.list
      sudo apt-get update
      sudo apt-get install -y netbird-ui libgtk-4-1 libwebkitgtk-6.0-4 xdg-utils
      ok "Installed"
    fi

  else
    echo "No pacman or apt-get found — this script only supports Arch-based and Debian-based Linux. Aborting."
    exit 1
  fi

  # ── Forgejo SSH key (per-device, not chezmoi-managed) ──────────────────────
  # dotfiles' own Forgejo key is shared across every machine that applies the
  # repo -- can't be used to clone dotfiles in the first place (chicken-and-
  # egg). Generate a key dedicated to this device instead; register its
  # public half on Forgejo manually before the chezmoi init step below.
  step "Forgejo SSH key"
  forgejo_key="$HOME/.ssh/keys/forgejo-$(hostname -s)"
  if [[ -f "$forgejo_key" ]]; then
    ok "Already exists ($forgejo_key)"
  else
    mkdir -p ~/.ssh/keys
    ssh-keygen -t ed25519 -C "forgejo-$(hostname -s)" -f "$forgejo_key" -N ""
    ok "Generated ($forgejo_key)"
  fi

  linux_next_steps "$forgejo_key"
  exit 0

else
  echo "Unsupported OS: $(uname). This script supports macOS and Linux (Arch-based or Debian-based). Aborting."
  exit 1
fi
