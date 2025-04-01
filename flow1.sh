#!/bin/bash
#
# secure-tier1.sh
# TIER 1 Security Setup
# - Creates a new sudo user
# - Provides four options:
#    (1) I have my own public key to add
#    (2) Let the script generate a new keypair
#    (3) Leave authorized_keys empty for now
#    (4) Enable password-based login (PasswordAuthentication yes)
# - Disables root login, logs everything to /etc/secure-me.json
#

set -euo pipefail

# 1) Must be run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  exit 1
fi

JSON_FILE="/etc/secflow/me.json"
  apt-get update -y

if ! command -v jq &>/dev/null; then
  echo "jq is not installed. Installing now..."
  apt-get install -y jq
  echo "jq has been installed."
fi

if [ ! -f "$JSON_FILE" ]; then
  echo '{"tiers": {}, "logs": []}' > "$JSON_FILE"
  chmod 600 "$JSON_FILE"
  echo "[!] Created /etc/secure-me.json for tracking."
fi

log_json() {
  local msg="$1"
  local ts
  ts="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  jq ".logs += [{\"timestamp\":\"$ts\", \"message\": \"$msg\"}]" "$JSON_FILE" > /tmp/secflow.tmp
  mv /tmp/secflow.tmp "$JSON_FILE"
  echo "[LOG] $msg"
}

mark_tier_installed() {
  local tier="$1"
  jq ".tiers.\"$tier\" = true" "$JSON_FILE" > /tmp/secflow.tmp
  mv /tmp/secflow.tmp "$JSON_FILE"
  log_json "TIER $tier has been marked as installed."
}

if jq -e '.tiers."1" == true' "$JSON_FILE" &>/dev/null; then
  echo "TIER 1 appears to be installed already. Do you want to reinstall it? (y/n)"
  read -r ans
  if [[ "$ans" != "y" ]]; then
    echo "Operation canceled."
    exit 0
  fi
  log_json "Reinstalling TIER 1."
else
  log_json "Starting TIER 1 installation."
fi

read -rp "Enter the new sudo username: " new_user
if [[ ! "$new_user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  echo "Error: Invalid username (only lowercase letters, digits, hyphens, underscores allowed)."
  exit 1
fi

if id "$new_user" &>/dev/null; then
  echo "User '$new_user' already exists."
else
  adduser --disabled-password --gecos "" "$new_user"
  usermod -aG sudo "$new_user"
  log_json "Created user '$new_user' with sudo privileges."
fi

mkdir -p "/home/$new_user/.ssh"
touch "/home/$new_user/.ssh/authorized_keys"
chmod 700 "/home/$new_user/.ssh"
chmod 600 "/home/$new_user/.ssh/authorized_keys"
chown -R "$new_user:$new_user" "/home/$new_user/.ssh"

echo "
Choose one of the following:
1) I already have a public key (add it now)
2) Let the script generate a new keypair
3) Leave authorized_keys empty
4) Enable password-based login (PasswordAuthentication yes)
"

read -rp "Your choice (1/2/3/4): " choice

case "$choice" in
  1)
    echo "Please enter your public key on a single line:"
    read -r pubkey
    echo "$pubkey" >> "/home/$new_user/.ssh/authorized_keys"
    log_json "User '$new_user' added their own public key to authorized_keys."
    ;;
  2)
    echo "Generating a 2048-bit RSA keypair..."
    mkdir -p /tmp/key-$new_user
    ssh-keygen -t rsa -b 2048 -f /tmp/key-$new_user/id_rsa -N ""
    cat /tmp/key-$new_user/id_rsa.pub >> "/home/$new_user/.ssh/authorized_keys"
    chown "$new_user:$new_user" "/home/$new_user/.ssh/authorized_keys"
    echo "Here is your private key (save it securely!):"
    cat /tmp/key-$new_user/id_rsa
    log_json "Script generated a keypair for '$new_user' and appended the public key to authorized_keys."
    ;;
  3)
    echo "Leaving authorized_keys empty for now."
    log_json "authorized_keys remains empty for user '$new_user'."
    ;;
  4)
    sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Please set a password for user '$new_user':"
    passwd "$new_user"
    log_json "Password-based login enabled for '$new_user'."
    ;;
  *)
    echo "Invalid selection. Exiting."
    exit 1
    ;;
esac

sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config

if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
  sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
fi

systemctl restart ssh
log_json "SSH config updated. Root login disabled."

mark_tier_installed 1

echo "[✔] TIER 1 installation completed."
if [[ "$choice" == "1" || "$choice" == "2" || "$choice" == "3" ]]; then
  echo "Public key scenario active, password-based login disabled."
else
  echo "Password-based login enabled."
fi
echo "Root login is disabled (PermitRootLogin no)."
echo "Logs are in: $JSON_FILE"
