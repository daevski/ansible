#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "==> Installing Ansible, Git, and pipx..."
sudo pacman -Sy --needed --noconfirm ansible-core git python-pipx vim

echo "==> Installing community.general collection..."
ansible-galaxy collection install community.general

echo "==> Configuring pipx..."
pipx ensurepath
pipx completions

echo ""
echo "==> System configuration"

read -rp "Hostname: " system_hostname
while [[ -z "$system_hostname" ]]; do
    echo "Hostname cannot be empty."
    read -rp "Hostname: " system_hostname
done

detected_locale=$(localectl status 2>/dev/null | awk '/System Locale/ {split($3,a,"="); print a[2]}')
read -rp "Locale [${detected_locale:-en_US.UTF-8}]: " system_locale
system_locale="${system_locale:-${detected_locale:-en_US.UTF-8}}"

detected_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
read -rp "Timezone [${detected_tz}]: " system_timezone
system_timezone="${system_timezone:-${detected_tz}}"

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
echo "    ansible-playbook -i inventory/hosts site.yml --ask-become-pass"
echo ""

exec $SHELL -l
