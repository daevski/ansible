# Ansible Todo

Things from kitbash not yet covered by Ansible, grouped by effort.

## Configuration tasks (non-trivial, not just package installs)

### Cursor theme (gsettings)
`cursor.sh` sets the GTK cursor via `gsettings` and writes env vars so
Electron/Chrome apps pick it up. The `breeze` package is already installed.
Missing: an Ansible task to call `gsettings set org.gnome.desktop.interface
cursor-theme breeze_cursors` and `cursor-size 20` as the user.

### Claude Code CLI
`claude.sh` installs via npm with a user-local prefix (`~/.npm-global`) so
no sudo is needed. `nodejs` and `npm` are already in the package list.
Missing: task to set npm prefix and run `npm install -g @anthropic-ai/claude-code`.

### Mounts
`mounts.sh` writes fstab entries for CIFS/NFS network shares and local drives,
creates mount points, and adds home symlinks. Classic Ansible territory —
probably a new `mounts` role mirroring the vars pattern from `kit.conf`
(`network_mounts`, `local_media` lists). Currently disabled in kit.conf but
the logic is well-defined.

### Hibernate
`hibernate.sh` creates a swapfile, adds it to fstab, and writes the resume
kernel parameter. Already manually configured on the laptop (swapfile at
`/swapfile`, fstab entry present, `resume=` and `resume_offset=` in
`GRUB_CMDLINE_LINUX_DEFAULT`) — but not codified in Ansible. Should live in
a task file gated by a `hibernate_enabled` var (default false) so it can be
applied consistently on new machines.

### Default shell (zsh) — post-provision re-login required
The `config.yml` task sets zsh as the default shell via `chsh`, which is
correct. However `chsh` only takes effect on next login, so a freshly
provisioned machine will still show bash until the user logs out and back
in. Consider adding a `debug` task at the end of the play reminding the
user to re-login, or document it in the README.

## Package gaps (simple additions when the feature is needed)

- **brightnessctl** — laptop backlight control; add to a `laptop` host group
  or `host_vars/laptop.yml` rather than `group_vars/all.yml`
- **wlsunset** — day/night color temperature; just needs a package entry +
  user service when enabled
- **easyeffects** — PipeWire audio processor; package + user service
- **qpwgraph** — PipeWire graph editor; package only

## Lower priority / occasional use

These are all currently disabled in kit.conf and only needed on specific machines:

- **discord** — AUR (`discord`)
- **moonlight** — AUR (`moonlight-qt-bin`), streaming client
- **sunshine** — AUR (`sunshine`), streaming server; machine-specific
- **zoom** — AUR or direct download
- **ollama** — tarball install as systemd service; good Ansible candidate
  if used regularly
- **Catppuccin GTK theme** — GitHub release download + extraction;
  currently `_theme=false` everywhere
