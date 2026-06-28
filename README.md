# Ansible Provisioning

Post-install provisioning for Arch Linux. Assumes base system installed with a `david` user account.

## Prerequisites

1. Install Ansible: `sudo pacman -S ansible`
2. Install the community.general collection: `ansible-galaxy collection install community.general`
3. Set `system_hostname`, `system_locale`, and `system_timezone` in `group_vars/all.yml` as needed

## Usage

Full provisioning run:

```bash
ansible-playbook -i inventory/hosts site.yml --ask-become-pass
```

Run a single role:

```bash
ansible-playbook -i inventory/hosts site.yml --tags packages --ask-become-pass
ansible-playbook -i inventory/hosts site.yml --tags system --ask-become-pass
ansible-playbook -i inventory/hosts site.yml --tags dotfiles
```

## Manual Steps After Provisioning

These require interactive authentication and cannot be automated:

- **NordVPN**: `nordvpn login`
- **Syncthing**: open <http://localhost:8384> and pair with existing devices
- **SSH keys**: `ssh-keygen -t ed25519 -C "hostname"` then add public key to GitHub

## Adding a Laptop

1. Add a `[laptop]` group to `inventory/hosts`
2. Create `group_vars/laptop.yml` with hardware-specific overrides (e.g. remove nvidia packages, add appropriate GPU/WiFi drivers)
3. Run: `ansible-playbook -i inventory/hosts site.yml --limit laptop --ask-become-pass`
