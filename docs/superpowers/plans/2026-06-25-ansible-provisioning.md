# Ansible Provisioning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a role-based Ansible playbook that provisions an Arch Linux desktop from a post-install state — packages, system config, services, and dotfiles.

**Architecture:** Three roles run in sequence: `packages` installs all pacman and AUR packages, `system` deploys config files and enables services, `dotfiles` clones the home git repo as a bare clone. Each role is independently runnable via tags.

**Tech Stack:** Ansible, `community.general.pacman` module, bash shell tasks for AUR, systemd module for services.

## Global Constraints

- Target: Arch Linux, post-install (user account already exists)
- Ansible user: `david` (UID 1000)
- AUR helper: `paru` (bootstrapped from AUR via makepkg if not present)
- No Ansible Galaxy roles; only `community.general` collection for the pacman module
- `makepkg` must never run as root — AUR tasks use `become_user: "{{ ansible_user }}"`
- sudoers files must be validated with `visudo -cf` before writing
- No secrets management; post-run manual steps documented in README

---

## File Map

```
~/code/daevski/ansible/
├── site.yml                                    Create
├── inventory/
│   └── hosts                                   Create
├── group_vars/
│   └── all.yml                                 Create
├── roles/
│   ├── packages/
│   │   ├── tasks/
│   │   │   ├── main.yml                        Create
│   │   │   ├── pacman.yml                      Create
│   │   │   └── aur.yml                         Create
│   │   └── vars/
│   │       └── main.yml                        Create
│   ├── system/
│   │   ├── tasks/
│   │   │   ├── main.yml                        Create
│   │   │   ├── config.yml                      Create
│   │   │   └── services.yml                    Create
│   │   ├── files/
│   │   │   ├── sddm.conf.d/
│   │   │   │   └── theme.conf                  Copy from ~/system-configs/sddm/sddm.conf.d/
│   │   │   ├── sddm-themes/
│   │   │   │   └── hyprlock-sddm-theme/        Copy from ~/system-configs/sddm/themes/
│   │   │   └── sudoers.d/
│   │   │       └── david-timeout               Copy from ~/system-configs/sudoers.d/
│   │   └── handlers/
│   │       └── main.yml                        Create
│   └── dotfiles/
│       └── tasks/
│           └── main.yml                        Create
└── README.md                                   Create
```

---

### Task 1: Project scaffold — site.yml, inventory, group_vars

**Files:**
- Create: `site.yml`
- Create: `inventory/hosts`
- Create: `group_vars/all.yml`

**Interfaces:**
- Produces: top-level playbook wiring all three roles with tags; inventory pointing at localhost; shared vars consumed by all roles

- [ ] **Step 1: Create site.yml**

```yaml
# site.yml
---
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

- [ ] **Step 2: Create inventory/hosts**

```ini
[desktop]
localhost ansible_connection=local
```

- [ ] **Step 3: Create group_vars/all.yml**

Update `dotfiles_repo` to the actual remote URL before first run.

```yaml
ansible_user: david
user_uid: 1000
dotfiles_repo: git@github.com:daevski/dotfiles.git
```

- [ ] **Step 4: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors. (Roles don't exist yet so you'll see a warning about missing roles — that's fine at this stage.)

- [ ] **Step 5: Commit**

```bash
git add site.yml inventory/hosts group_vars/all.yml
git commit -m "scaffold: add site.yml, inventory, and group_vars"
```

---

### Task 2: packages role — pacman packages

**Files:**
- Create: `roles/packages/vars/main.yml`
- Create: `roles/packages/tasks/pacman.yml`
- Create: `roles/packages/tasks/main.yml`

**Interfaces:**
- Consumes: `pacman_packages` list defined in `roles/packages/vars/main.yml`
- Produces: all official packages installed idempotently via `community.general.pacman`

- [ ] **Step 1: Create roles/packages/vars/main.yml**

```yaml
---
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
  - obsidian
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
  - rtl8821au-dkms-git
  - synology-drive
  - visual-studio-code-bin
```

- [ ] **Step 2: Create roles/packages/tasks/pacman.yml**

```yaml
---
- name: Install official packages
  community.general.pacman:
    name: "{{ pacman_packages }}"
    state: present
    update_cache: yes
```

- [ ] **Step 3: Create roles/packages/tasks/main.yml**

```yaml
---
- import_tasks: pacman.yml
```

(aur.yml import added in Task 3)

- [ ] **Step 4: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 5: Commit**

```bash
git add roles/packages/
git commit -m "packages: add pacman role with official package list"
```

---

### Task 3: packages role — AUR packages

**Files:**
- Create: `roles/packages/tasks/aur.yml`
- Modify: `roles/packages/tasks/main.yml`

**Interfaces:**
- Consumes: `aur_packages` from `roles/packages/vars/main.yml`; `ansible_user` from `group_vars/all.yml`
- Produces: paru installed and all AUR packages present; each install is idempotent via `pacman -Qi` check

- [ ] **Step 1: Create roles/packages/tasks/aur.yml**

```yaml
---
- name: Check if paru is installed
  command: pacman -Qi paru
  register: paru_check
  failed_when: false
  changed_when: false

- name: Clone paru from AUR
  git:
    repo: https://aur.archlinux.org/paru.git
    dest: /tmp/paru-build
  when: paru_check.rc != 0
  become: yes
  become_user: "{{ ansible_user }}"

- name: Build and install paru
  command: makepkg -si --noconfirm
  args:
    chdir: /tmp/paru-build
  when: paru_check.rc != 0
  become: yes
  become_user: "{{ ansible_user }}"

- name: Install AUR packages
  shell: pacman -Qi {{ item }} > /dev/null 2>&1 || paru -S --noconfirm {{ item }}
  loop: "{{ aur_packages }}"
  become: yes
  become_user: "{{ ansible_user }}"
  changed_when: false
```

- [ ] **Step 2: Update roles/packages/tasks/main.yml**

```yaml
---
- import_tasks: pacman.yml
- import_tasks: aur.yml
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 4: Commit**

```bash
git add roles/packages/tasks/aur.yml roles/packages/tasks/main.yml
git commit -m "packages: add AUR role with paru bootstrap and package installs"
```

---

### Task 4: system role — config files

**Files:**
- Copy: `~/system-configs/sddm/sddm.conf.d/theme.conf` → `roles/system/files/sddm.conf.d/theme.conf`
- Copy: `~/system-configs/sddm/themes/hyprlock-sddm-theme/` → `roles/system/files/sddm-themes/hyprlock-sddm-theme/`
- Copy: `~/system-configs/sudoers.d/david-timeout` → `roles/system/files/sudoers.d/david-timeout`
- Create: `roles/system/tasks/config.yml`
- Create: `roles/system/handlers/main.yml`
- Create: `roles/system/tasks/main.yml`

**Interfaces:**
- Produces: sddm config and theme at correct system paths; sudoers timeout rule validated and written; sddm restart handler registered

- [ ] **Step 1: Copy source files into the role**

```bash
mkdir -p roles/system/files/sddm.conf.d
mkdir -p roles/system/files/sddm-themes
mkdir -p roles/system/files/sudoers.d

cp ~/system-configs/sddm/sddm.conf.d/theme.conf roles/system/files/sddm.conf.d/
cp -r ~/system-configs/sddm/themes/hyprlock-sddm-theme roles/system/files/sddm-themes/
cp ~/system-configs/sudoers.d/david-timeout roles/system/files/sudoers.d/
```

Do NOT copy `user-timeout.template` — it is not a deployable file.

- [ ] **Step 2: Create roles/system/handlers/main.yml**

```yaml
---
- name: restart sddm
  systemd:
    name: sddm
    state: restarted
```

- [ ] **Step 3: Create roles/system/tasks/config.yml**

```yaml
---
- name: Copy sddm theme config
  copy:
    src: sddm.conf.d/theme.conf
    dest: /etc/sddm.conf.d/theme.conf
    owner: root
    group: root
    mode: '0644'
  notify: restart sddm

- name: Copy hyprlock-sddm-theme
  copy:
    src: sddm-themes/hyprlock-sddm-theme/
    dest: /usr/share/sddm/themes/hyprlock-sddm-theme/
    owner: root
    group: root
    mode: '0644'
  notify: restart sddm

- name: Copy sudoers timeout rule
  copy:
    src: sudoers.d/david-timeout
    dest: /etc/sudoers.d/david-timeout
    owner: root
    group: root
    mode: '0440'
    validate: visudo -cf %s
```

- [ ] **Step 4: Create roles/system/tasks/main.yml**

```yaml
---
- import_tasks: config.yml
```

(services.yml import added in Task 5)

- [ ] **Step 5: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 6: Commit**

```bash
git add roles/system/
git commit -m "system: add config role with sddm and sudoers files"
```

---

### Task 5: system role — services

**Files:**
- Create: `roles/system/tasks/services.yml`
- Modify: `roles/system/tasks/main.yml`

**Interfaces:**
- Consumes: `ansible_user` and `user_uid` from `group_vars/all.yml`
- Produces: system and user services enabled and started

- [ ] **Step 1: Create roles/system/tasks/services.yml**

```yaml
---
- name: Enable and start system services
  systemd:
    name: "{{ item }}"
    enabled: yes
    state: started
    daemon_reload: yes
  loop:
    - bluetooth
    - docker
    - NetworkManager
    - nordvpnd
    - sddm

- name: Enable and start user services
  systemd:
    name: "{{ item }}"
    enabled: yes
    state: started
    scope: user
  loop:
    - dropbox
    - hypridle
    - pipewire
    - pipewire-pulse
    - syncthing
    - wireplumber
  become: yes
  become_user: "{{ ansible_user }}"
  environment:
    XDG_RUNTIME_DIR: "/run/user/{{ user_uid }}"
```

- [ ] **Step 2: Update roles/system/tasks/main.yml**

```yaml
---
- import_tasks: config.yml
- import_tasks: services.yml
```

- [ ] **Step 3: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 4: Commit**

```bash
git add roles/system/tasks/services.yml roles/system/tasks/main.yml
git commit -m "system: add services role for system and user service enablement"
```

---

### Task 6: dotfiles role

**Files:**
- Create: `roles/dotfiles/tasks/main.yml`

**Interfaces:**
- Consumes: `dotfiles_repo` and `ansible_user` from `group_vars/all.yml`
- Produces: bare clone at `~/.dotfiles-git`; dotfiles checked out into home, overwriting any conflicting system defaults

- [ ] **Step 1: Create roles/dotfiles/tasks/main.yml**

```yaml
---
- name: Clone dotfiles as bare repo
  git:
    repo: "{{ dotfiles_repo }}"
    dest: "/home/{{ ansible_user }}/.dotfiles-git"
    bare: yes
  become: yes
  become_user: "{{ ansible_user }}"

- name: Checkout dotfiles into home
  command: >
    git --git-dir=/home/{{ ansible_user }}/.dotfiles-git
        --work-tree=/home/{{ ansible_user }}
        checkout -f
  become: yes
  become_user: "{{ ansible_user }}"
```

- [ ] **Step 2: Verify syntax**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 3: Commit**

```bash
git add roles/dotfiles/
git commit -m "dotfiles: add role to bare-clone and checkout home git repo"
```

---

### Task 7: README

**Files:**
- Create: `README.md`

**Interfaces:**
- Produces: documentation for prerequisites, running the playbook, and manual post-run steps

- [ ] **Step 1: Create README.md**

```markdown
# Ansible Provisioning

Post-install provisioning for Arch Linux. Assumes base system installed with a `david` user account.

## Prerequisites

1. Install Ansible: `sudo pacman -S ansible`
2. Install the community.general collection: `ansible-galaxy collection install community.general`
3. Add your SSH key to GitHub (required for dotfiles clone)
4. Verify `dotfiles_repo` in `group_vars/all.yml` points to your dotfiles remote

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
- **Dropbox**: launch Dropbox and complete browser authentication
- **Syncthing**: open <http://localhost:8384> and pair with existing devices
- **SSH keys**: `ssh-keygen -t ed25519 -C "hostname"` then add public key to GitHub

## Adding a Laptop

1. Add a `[laptop]` group to `inventory/hosts`
2. Create `group_vars/laptop.yml` with hardware-specific overrides (e.g. remove nvidia packages, add appropriate GPU/WiFi drivers)
3. Run: `ansible-playbook -i inventory/hosts site.yml --limit laptop --ask-become-pass`
```

- [ ] **Step 2: Verify syntax one final time**

Run: `ansible-playbook -i inventory/hosts site.yml --syntax-check`

Expected output:
```
playbook: site.yml
```
No errors.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with prerequisites and usage instructions"
```
