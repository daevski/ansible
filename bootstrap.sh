#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/daevski/ansible.git"
REPO_DIR="$HOME/code/daevski/ansible"

echo "==> Installing Ansible, Git, and pipx..."
sudo pacman -Sy --needed --noconfirm ansible-core git python-pipx vim

echo "==> Cloning ansible repo..."
if [[ ! -d "$REPO_DIR" ]]; then
    git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

echo "==> Installing community.general collection..."
ansible-galaxy collection install community.general

echo "==> Configuring pipx..."
pipx ensurepath
pipx completions

echo ""
echo "************************************************************"
echo "*                   SYSTEM CONFIGURATION                   *"
echo "************************************************************"
echo ""

read -rp "Hostname: " system_hostname </dev/tty
while [[ -z "$system_hostname" ]]; do
    echo "Hostname cannot be empty."
    read -rp "Hostname: " system_hostname </dev/tty
done

detected_locale=$(localectl status 2>/dev/null | awk '/System Locale/ {split($3,a,"="); print a[2]}') || true
read -rp "Locale [${detected_locale:-en_US.UTF-8}]: " system_locale </dev/tty
system_locale="${system_locale:-${detected_locale:-en_US.UTF-8}}"

detected_tz=$(timedatectl show --property=Timezone --value 2>/dev/null) || true
read -rp "Timezone (e.g. America/New_York) [${detected_tz:-UTC}]: " system_timezone </dev/tty
system_timezone="${system_timezone:-${detected_tz:-UTC}}"

echo "" >> host_vars/localhost.yml
echo "system_hostname: \"${system_hostname}\"" >> host_vars/localhost.yml
echo "system_locale: \"${system_locale}\"" >> host_vars/localhost.yml
echo "system_timezone: \"${system_timezone}\"" >> host_vars/localhost.yml

echo ""
echo "==> Configuration written to host_vars/localhost.yml"
echo "    hostname: ${system_hostname}"
echo "    locale:   ${system_locale}"
echo "    timezone: ${system_timezone}"
echo ""
echo "==> Ready. Run the playbook with:"
echo "    cd ${REPO_DIR}"
echo "    ansible-playbook -i inventory/hosts site.yml --ask-become-pass"
echo ""

exec $SHELL -l
