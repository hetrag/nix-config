# Server migration runbook

From docker/portainer on the old server → NixOS (this flake). The plan:
reinstall the OS disk only, bring the docker stacks back up unchanged
("stepping stone"), then migrate stack by stack to native services.

Deliberately dropped from the old setup: **nextcloud-aio** (re-add later if
needed), **portainer** (replaced by this repo), **nginx-proxy-manager**
(replaced by caddy), **pi-hole** (replaced by adguard-home).

End state: native immich, vikunja, open-webui (OIDC via authentik), syncthing,
sonarr/radarr/sabnzbd, postgres, caddy, adguard-home, authentik, kopia.
Containers only for qdrant (no NixOS module).

## 0. Before touching the server — fill in the TODOs

Search the repo for `TODO` and `REPLACE-ME`:

- `hosts/server/hardware-configuration.nix` — placeholder; generate the real
  one at install (`nixos-generate-config --root /mnt`) and commit it.
- `hosts/server/default.nix` — `networking.hostId` (on the server:
  `head -c 8 /etc/machine-id`) and the zfs pool/dataset names for
  `/mnt/raid` and `/mnt/ssd` (`zpool status` after importing).
- `modules/services/caddy.nix` — ACME email + confirm subdomains (check what
  nginx-proxy-manager currently answers for immich/open-webui).
- `modules/core/default.nix` — NFS server IP `192.168.1.130`: confirm the new
  server keeps this address (DHCP reservation).

### Harvest from the old server (before the reinstall!)

From portainer's stack env / the host:

- [ ] the **real** `DB_USERNAME`/`DB_PASSWORD` (the containerized databases
      keep the passwords their volumes were initialized with — the values in
      `docker_configs/.env` are stale)
- [ ] the **real** kopia repository password
- [ ] list of subdomains in nginx-proxy-manager
- [ ] pi-hole: DNS records + blocklists (re-enter in adguard)

Then take a kopia snapshot of `/mnt/ssd/server_config` and dump both
databases (`immich`, `vikunja`) with `pg_dump -Fc`.

## 1. Bootstrap sops (once, from any machine with the repo)

```bash
# personal edit key (never commit ~/.config/sops/age/keys.txt)
nix-shell -p age -c age-keygen -o ~/.config/sops/age/keys.txt

# per machine, on that machine as root (do server first):
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Paste the three public keys into `.sops.yaml` (replacing the REPLACE_ME
placeholders), then create the secrets:

```bash
nix-shell -p sops -c sops secrets/secrets.yaml
```

Keys to create (keep `anthropic_auth_token` and `ssh_key` that are already
there):

```yaml
stepping-stone:
  db_password: <the CURRENT real DB password from portainer>
  vikunja_service_secret: <openssl rand -base64 32>
  kopia_repo_password: <the CURRENT real kopia repo password>
vikunja:
  service_secret: <openssl rand -base64 32>
authentik:
  secret_key: <openssl rand -base64 60>
kopia:
  server_password: <openssl rand -base64 24>
  repo_password: <same value as stepping-stone.kopia_repo_password>
```

No postgres password is needed anywhere: native services use unix-socket
peer auth.

## 2. Install day

Prepare, while the old server is still running:

- **Install Nix on the laptop you edit this repo from** (it has no nix —
  that also means none of this flake has ever been evaluated):
  `sh <(curl -L https://nixos.org/nix/install)`, then from the repo:
  `nix build .#nixosConfigurations.server.config.system.build.toplevel`
  This builds the whole server config offline of the server and catches
  errors while nothing is at stake. Fix anything it reports, commit.
- Harvest the portainer values + take the dumps/snapshot (section 0).
- Push the repo somewhere the server can reach (or carry it on the USB stick).

Install:

1. Write the NixOS 26.05 minimal ISO to a USB stick, boot the server from it.
2. Identify the disks — OS disk vs the raid/ssd data disks:
   `lsblk -o NAME,SIZE,MODEL,SERIAL`
3. Partition ONLY the OS disk (config expects UEFI + systemd-boot):
   ```
   DISK=/dev/disk/by-id/ata-YOUR-OS-DISK
   sudo sgdisk --zap-all $DISK
   sudo sgdisk -n 1:0:+1G -t 1:EF00 $DISK    # /boot (ESP)
   sudo sgdisk -n 2:0:0   -t 2:8300 $DISK    # /
   sudo mkfs.vfat -F32 -n BOOT ${DISK}-part1
   sudo mkfs.ext4 -L nixos  ${DISK}-part2
   sudo mount ${DISK}-part2 /mnt
   sudo mkdir -p /mnt/boot
   sudo mount ${DISK}-part1 /mnt/boot
   ```
   Do NOT mount /mnt/raid or /mnt/ssd here — the system mounts them on
   first boot. (The data disks are zfs pools: leave them completely alone
   during install — no import, no mount. Import + set mountpoints after
   first boot, as described in `hosts/server/default.nix`.)
4. Generate + merge hardware config:
   `sudo nixos-generate-config --root /mnt`, then copy
   `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder at
   `hosts/server/hardware-configuration.nix`, and fill the zfs TODOs in
   `hosts/server/default.nix` (`networking.hostId` + the pool names). Put
   the repo at e.g. `/tmp/nix-config` on the installer.
5. Install — the first full build happens here; if it errors, fix and
   re-run (nothing is written to disk until the build succeeds):
   ```
   cd /tmp/nix-config
   sudo nixos-install --flake .#server
   ```
   (If the installer complains flakes aren't enabled, prefix the command
   with `NIX_CONFIG="experimental-features = nix-command flakes"`.)
   Set the root password when prompted, unplug the USB stick, reboot.

### First boot (console, as root)

1. Log in as root (the password from nixos-install). Then as mig (console,
   password `change-me` from core): set a real password with `passwd`, put
   your SSH public key into `users.users.mig.openssh.authorizedKeys.keys`
   in `modules/core`, and delete `initialPassword`.
2. Give sops this host's key: `ssh-to-age <
   /etc/ssh/ssh_host_ed25519_key.pub`. On the laptop, paste it into
   `.sops.yaml` (`&server`), re-encrypt and commit:
   `nix-shell -p sops -c sops updatekeys secrets/secrets.yaml`
3. On the server: pull the repo, `sudo nixos-rebuild switch --flake .#server`,
   then restart the stacks (they started before the secrets existed):
   `sudo systemctl restart 'stack-*'`
4. `sudo tailscale up` (then on laptop/desktop too).
5. Adguard: open `http://<server>:8053`, initial setup, import blocklists,
   add DNS rewrite `*.jgelectronics.dk -> <server LAN IP>`.
6. Router: DHCP DNS still points at the server (pi-hole's old job), and the
   server keeps 192.168.1.130 (DHCP reservation).
7. Verify: caddy issued certs (`journalctl -u caddy`), NFS mounts work from
   laptop/desktop, every app answers on its usual URL, kopia UI works.

## 3. Migrations, one at a time

For each: stop the stack, move data, enable the module in
`hosts/server/default.nix` (uncomment the import), `nixos-rebuild switch`,
test a few days, then delete the stack (unit + `.yml` + entry in the `stacks`
list) and tighten the firewall port list. Rollback if anything breaks:
`nixos-rebuild switch --rollback` and `docker compose up` the old stack.

Roughly in this order (easy → hard):

### syncthing
`docker compose -f /etc/stepping-stone/syncthing/compose.yml down`.
Config dir is used in place (`/mnt/ssd/server_config/syncthing`) — just
`chown -R syncthing:media` it and the shared folders. Enable the module.
Later (optional): declare folders/devices in `settings` instead of the UI.

### arr (sonarr/radarr/sabnzbd)
Down the stack, then per app:
`rsync -a /mnt/ssd/server_config/sonarr/ /var/lib/sonarr/` (etc.),
`chown -R sonarr:media /var/lib/sonarr` (etc.), enable `arr.nix`, set
**umask 002** in each app's UI (Settings → Media Management), delete stack,
remove 8989/7878/8181 from the firewall (tailnet access remains).

### open-webui
`rsync -a /mnt/ssd/server_config/open-webui/ /var/lib/open-webui/`, enable
`open-webui.nix` (systemd assigns ownership of the state dir on start),
delete stack + the 3000 firewall port.

### postgres + vikunja
Enable `postgres.nix`. Then:
`docker compose -f .../vikunja/compose.yml exec vikunja-db pg_dump -U postgres -Fc vikunja > vikunja.dump`,
`sudo -u postgres pg_restore -d vikunja --no-owner vikunja.dump`
(after `ensureDatabases` created it), move
`/mnt/ssd/server_config/vikunja/files` to `/var/lib/vikunja/files`, enable
`vikunja.nix`, delete stack.

### authentik
Enable `authentik.nix`. First login:
`https://auth.jgelectronics.dk/if/flow/initial-setup/`.
Create OAuth2 clients: `immich`, `open-webui`. Wire the secrets in
`immich.nix` / `open-webui.nix` (commented TODOs show where).

### immich (the big one)
Dump from the vectorchord container, enable `immich.nix` (brings its own
postgres + vectorchord), restore, `chown -R immich:media /mnt/raid/media/immich`,
verify ML + OIDC, delete stack. A detailed docker→NixOS walkthrough:
https://diogotc.com/blog/immich-docker-to-nixos/

Note: media files become immich-only (mode 0700 on the library) — access via
the app; kopia (running as root) still backs the directory up.

### kopia (last)
`kopia.nix` is a draft — verify its `kopia server start` flags against the
packaged version, migrate the config dir as-is, enable, delete the container
(and its dangerous flags with it).

## 4. End state checklist

- [ ] firewall: only 22, 53, 80, 443, 2049 (+ syncthing 22000/21027, adguard
      web) — everything else via caddy or tailnet
- [ ] adguard `mutableSettings = false` once the config is settled
- [ ] portainer env values rotated out of use; the stale secrets in
      `docker_configs/.env` are not used anywhere
- [ ] `nix flake check` / eval from a nix-enabled machine before each
      rebuild (this repo is authored on a machine without nix)
