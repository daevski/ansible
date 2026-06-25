# Ansible Provisioning Design

**Date:** 2026-06-25
**Project:** `~/code/daevski/ansible/`
**Scope:** Post-install provisioning for Arch Linux desktop; extensible to a future laptop

---

## Overview

A role-based Ansible playbook that provisions an Arch Linux system from a clean base install. Assumes a user account exists and the machine is booted into a working system. Handles package installation (official + AUR), system configuration, service enablement, and dotfiles deployment.

Dotfiles remain in their own home-directory git repo and are not managed by Ansible beyond cloning them into place.

---

## Project Structure

```
~/code/daevski/ansible/
├── site.yml
├── inventory/
│   └── hosts
├── group_vars/
│   └── all.yml
├── roles/
│   ├── packages/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── pacman.yml
│   │   │   └── aur.yml
│   │   └── vars/
│   │       └── main.yml
│   ├── system/
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── services.yml
│   │   │   └── config.yml
│   │   ├── files/
│   │   │   ├── sddm.conf.d/
│   │   │   └── sudoers.d/
│   │   └── handlers/
│   │       └── main.yml
│   └── dotfiles/
│       └── tasks/
│           └── main.yml
└── README.md
```

---

## Roles

### packages

Installs all packages. Runs first.

**`tasks/pacman.yml`** — uses `community.general.pacman` module to install official packages in one idempotent operation.

**`tasks/aur.yml`** — two steps:
1. Bootstrap paru if not present via `makepkg` (runs as the target user; makepkg refuses root)
2. Install each AUR package with `pacman -Qi <pkg> || paru -S --noconfirm <pkg>`

`paru` itself is the bootstrap target and is not listed in `aur_packages`.

**`vars/main.yml`** — two lists:

```yaml
pacman_packages:
  - alacritty
  - alsa-utils
  - audacity
  - base
  - base-devel
  - bind
  - bluez
  - bluez-utils
  - breeze
  - cifs-utils
  - copyq
  - docker
  - docker-compose
  - dosfstools
  - fd
  - firefox
  - freerdp
  - fzf
  - git
  - gnome-calculator
  - go
  - grim
  - gvfs
  - hypridle
  - hyprlock
  - imagemagick
  - jq
  - kdiff3
  - less
  - lib32-libpulse
  - lib32-nvidia-utils
  - linux
  - linux-firmware
  - linux-headers
  - mako
  - networkmanager
  - nfs-utils
  - niri
  - nodejs
  - npm
  - nvidia-open
  - nvidia-settings
  - nvidia-utils
  - openssh
  - pacman-contrib
  - pipewire-alsa
  - pipewire-pulse
  - prismlauncher
  - python-pipx
  - qt5-quickcontrols2
  - remmina
  - rofi
  - rsync
  - sddm
  - slurp
  - steam
  - sudo
  - swappy
  - swaybg
  - syncthing
  - thunar
  - thunar-volman
  - unzip
  - uv
  - vim
  - waybar
  - wget
  - wimlib
  - wireplumber
  - xwayland-satellite
  - zoxide
  - zsh

aur_packages:
  - google-chrome
  - nordvpn-bin
  - obsidian
  - rtl8821au-dkms-git
  - synology-drive
  - visual-studio-code-bin
```

### system

Configures system-level settings. Runs second. Requires `become: yes`.

**`tasks/config.yml`** — copies files from `roles/system/files/` into place:
- `sddm.conf.d/` → `/etc/sddm.conf.d/`
- `sudoers.d/` → `/etc/sudoers.d/` (validated with `visudo -cf` before writing)

Source files are copied from `~/system-configs/` into the role at project creation time.

**`tasks/services.yml`** — enables services via the `systemd` module:

System-level:
- `bluetooth`, `docker`, `NetworkManager`, `nordvpnd`, `sddm`

User-level (`become_user: {{ ansible_user }}`, `scope: user`):
- `dropbox`, `hypridle`, `pipewire`, `pipewire-pulse`, `syncthing`, `wireplumber`

**`handlers/main.yml`** — restarts sddm when its config changes.

### dotfiles

Clones the home git repo onto the machine. Runs last, no root required.

Uses a bare clone to avoid conflicts with files already present in home from the base install:

```yaml
- name: Clone dotfiles as bare repo
  git:
    repo: "{{ dotfiles_repo }}"
    dest: "{{ ansible_env.HOME }}/.dotfiles-git"
    bare: yes

- name: Checkout dotfiles into home
  command: >
    git --git-dir={{ ansible_env.HOME }}/.dotfiles-git
        --work-tree={{ ansible_env.HOME }}
        checkout -f
```

The `-f` flag overwrites any conflicting system-default files (`.bashrc`, etc.) with the versioned copies.

---

## Inventory and Variables

**`inventory/hosts`:**
```ini
[desktop]
localhost ansible_connection=local
```

**`group_vars/all.yml`:**
```yaml
ansible_user: david
dotfiles_repo: git@github.com:daevski/dotfiles.git
```

When a laptop is added, create a `[laptop]` group and override hardware-specific vars (e.g., exclude nvidia packages, include different WiFi drivers).

---

## Top-Level Playbook

**`site.yml`:**
```yaml
- hosts: desktop
  become: yes
  roles:
    - role: packages
      tags: packages
    - role: system
      tags: system
    - role: dotfiles
      tags: dotfiles
```

---

## Running the Playbook

```bash
# Full provisioning
ansible-playbook -i inventory/hosts site.yml --ask-become-pass

# Single role
ansible-playbook -i inventory/hosts site.yml --tags packages --ask-become-pass
ansible-playbook -i inventory/hosts site.yml --tags system --ask-become-pass
ansible-playbook -i inventory/hosts site.yml --tags dotfiles
```

**Prerequisites:**
- `ansible` installed (`pacman -S ansible`)
- `community.general` collection: `ansible-galaxy collection install community.general`
- SSH key added to GitHub (for dotfiles clone)

---

## Manual Post-Run Steps

These cannot be automated without secrets and are documented for reference:

- **NordVPN**: `nordvpn login`
- **Dropbox**: launch and complete browser auth
- **Syncthing**: open web UI, pair with existing devices
- **SSH keys**: generate per-machine (`ssh-keygen`) and add public key to GitHub/other services

---

## Out of Scope

- Disk partitioning and base Arch install
- Secrets management (no Vault)
- Dotfiles content (managed in the separate home git repo)
- Laptop-specific configuration (deferred until hardware is known)
