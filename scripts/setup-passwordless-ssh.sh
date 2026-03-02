#!/usr/bin/env bash
set -euo pipefail

# Disable SSH password login on Ubuntu, handling cloud-init overrides.
# Usage:
#   sudo bash disable-ssh-password.sh
#
# After running, test from your client:
#   ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no user@server_ip

SSHD_MAIN="/etc/ssh/sshd_config"
SSHD_DIR="/etc/ssh/sshd_config.d"
CLOUD_SSHD="${SSHD_DIR}/50-cloud-init.conf"
OVERRIDE="${SSHD_DIR}/99-disable-password.conf"
CLOUD_CFG_CUSTOM="/etc/cloud/cloud.cfg.d/99-custom-ssh.cfg"

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Please run as root (use sudo)." >&2
    exit 1
  fi
}

ensure_dir() {
  mkdir -p "$SSHD_DIR"
}

# Replace or add a simple "Key value" sshd_config directive in a file.
set_sshd_kv() {
  local file="$1"
  local key="$2"
  local value="$3"

  touch "$file"

  if grep -qiE "^[[:space:]]*${key}[[:space:]]+" "$file"; then
    # Replace existing (case-insensitive key)
    perl -0777 -i -pe "s/^[[:space:]]*${key}[[:space:]]+.*/${key} ${value}/gmi" "$file"
  else
    printf "\n%s %s\n" "$key" "$value" >> "$file"
  fi
}

# Ensure the Include line exists so sshd_config.d files are read (Ubuntu typically has this already).
ensure_include() {
  if ! grep -qE "^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf" "$SSHD_MAIN" 2>/dev/null; then
    echo "NOTE: No Include for sshd_config.d found in $SSHD_MAIN; adding it."
    printf "\nInclude /etc/ssh/sshd_config.d/*.conf\n" >> "$SSHD_MAIN"
  fi
}

# Set cloud-init config knob to avoid re-enabling SSH password auth (best effort).
set_cloud_init_ssh_pwauth_false() {
  if [[ -d /etc/cloud/cloud.cfg.d ]] || [[ -f /etc/cloud/cloud.cfg ]]; then
    mkdir -p "$(dirname "$CLOUD_CFG_CUSTOM")"
    if [[ -f "$CLOUD_CFG_CUSTOM" ]] && grep -qE '^[[:space:]]*ssh_pwauth:' "$CLOUD_CFG_CUSTOM"; then
      perl -0777 -i -pe 's/^[[:space:]]*ssh_pwauth:.*/ssh_pwauth: false/gm' "$CLOUD_CFG_CUSTOM"
    else
      # Minimal YAML snippet; safe to coexist with other files
      cat > "$CLOUD_CFG_CUSTOM" <<'YAML'
# Ensure cloud-init does not re-enable SSH password authentication
ssh_pwauth: false
YAML
    fi
  fi
}

restart_ssh() {
  # Validate syntax before restart
  sshd -t
  systemctl restart ssh
}

print_effective() {
  echo
  echo "Effective sshd settings:"
  sshd -T | grep -iE 'passwordauthentication|kbdinteractiveauthentication|challengeresponseauthentication|usepam|permitrootlogin' || true
}

main() {
  require_root
  ensure_dir
  ensure_include

  # If cloud-init file exists, modify it directly (matches your experience).
  # Otherwise, create an override in sshd_config.d.
  local target_file="$OVERRIDE"
  if [[ -f "$CLOUD_SSHD" ]]; then
    echo "Found cloud-init sshd config: $CLOUD_SSHD"
    echo "Updating it (cloud images often override other files)."
    target_file="$CLOUD_SSHD"
  else
    echo "No $CLOUD_SSHD found; writing override: $OVERRIDE"
    target_file="$OVERRIDE"
  fi

  echo "Applying settings to: $target_file"
  set_sshd_kv "$target_file" "PasswordAuthentication" "no"
  set_sshd_kv "$target_file" "KbdInteractiveAuthentication" "no"
  set_sshd_kv "$target_file" "ChallengeResponseAuthentication" "no"

  # Optional hardening (uncomment if desired):
  # set_sshd_kv "$target_file" "PermitRootLogin" "prohibit-password"

  # Best-effort: prevent cloud-init from flipping it back later
  set_cloud_init_ssh_pwauth_false

  echo "Validating and restarting SSH..."
  restart_ssh

  print_effective

  echo
  echo "Done."
  echo "Test from your client (should FAIL and not allow password login):"
  echo "  ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no user@server_ip"
  echo
  echo "Test normal key login:"
  echo "  ssh user@server_ip"
}

main "$@"
