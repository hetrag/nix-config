# Server migration runbook

From docker/portainer on the old server → NixOS (this flake). The plan:
reinstall the OS disk only, bring the docker stacks back up unchanged
("stepping stone"), then migrate stack by stack to native services.

Install is deliberately phased, so only one thing can be wrong at a time:

1. **bare boot** (§2) — no services, no NFS, ssh only. `hosts/server/default.nix`
   ships in this state: every service import is commented out and the pool
   mounts carry `noauto`, which keeps zfs off the boot path.
2. **zfs** (§3) — import the two data pools and confirm they come back on
   reboot.
3. **services** (§4) — uncomment caddy, adguard and the stepping-stone stacks.
4. **migrations** (§5) — one stack at a time, native.

Deliberately dropped from the old setup: **nextcloud-aio** (re-add later if
needed), **portainer** (replaced by this repo), **nginx-proxy-manager**
(replaced by caddy), **pi-hole** (replaced by adguard-home).

End state: native immich, vikunja, open-webui (OIDC via authentik), syncthing,
sonarr/radarr/sabnzbd, postgres, caddy, adguard-home, authentik, kopia.
Containers only for qdrant (no NixOS module).

## 0. Before touching the server — fill in the TODOs

Search the repo for `TODO` and `CHANGE-ME`:

- `hosts/server/hardware-configuration.nix` — placeholder; generate the real
  one at install (`nixos-generate-config --root /mnt`) and commit it.
- `modules/services/caddy.nix` — ACME email + confirm subdomains (check what
  nginx-proxy-manager currently answers for immich/open-webui).
- `modules/core/default.nix` — NFS server IP `192.168.1.130`: confirm the new
  server keeps this address (DHCP reservation on the **new** NIC's MAC).

Already decided, do not change: `networking.hostId = "1767aa3a"` (the pools
get stamped with it on first import) and the pool names `raid` / `ssd` in
`hosts/server/default.nix`.

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

## 1. Bootstrap sops

Mostly done: `.sops.yaml` already carries `&mig`, `&laptop` and `&server`,
and `secrets/secrets.yaml` already holds `anthropic_auth_token`, `ssh_key`
and the `stepping-stone:` map. What is still open:

- `&server` is the **old** machine's host key. The reinstall generates a new
  one, so it must be replaced (install step 5, or first boot step 3).
- `&desktop` is commented out until that machine exists.

Reference, for a machine that needs a key:

```bash
# personal edit key (never commit ~/.config/sops/age/keys.txt)
nix-shell -p age -c age-keygen -o ~/.config/sops/age/keys.txt

# per machine, on that machine as root:
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

Paste the age key into `.sops.yaml`, then
`nix-shell -p sops --run 'sops updatekeys secrets/secrets.yaml'` and commit.

Edit secrets with `nix-shell -p sops -c sops secrets/secrets.yaml`. Keys the
later phases still need (keep the ones already there):

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
  ```bash
  nix --extra-experimental-features 'nix-command flakes' \
    build .#nixosConfigurations.server.config.system.build.toplevel
  ```
  This builds the whole server config away from the server and catches
  errors while nothing is at stake. Fix anything it reports, commit.
- Harvest the portainer values + take the dumps/snapshot (section 0).
- Push the repo somewhere the server can reach (or carry it on the USB
  stick, together with `~/.config/sops/age/keys.txt` if you want to finish
  sops during the install — step 5 below).

Install:

1. Write the NixOS 26.05 minimal ISO to a USB stick, boot the server from
   it. Confirm it booted in UEFI mode — the config uses systemd-boot:
   `ls /sys/firmware/efi` must exist.
2. Identify the disks — OS disk vs the raid/ssd data disks:
   `lsblk -o NAME,SIZE,MODEL,SERIAL`. Sanity-check the pools are intact
   *without* importing them: `sudo zpool import` (no pool name) just lists
   what it finds. Note the exact pool names it prints.
3. Partition ONLY the OS disk:
   ```bash
   DISK=/dev/disk/by-id/ata-YOUR-OS-DISK
   sudo sgdisk --zap-all $DISK
   sudo sgdisk -n 1:0:+1G -t 1:EF00 $DISK    # /boot (ESP)
   sudo sgdisk -n 2:0:+1000G   -t 2:8300 $DISK    # /
   sudo sgdisk -n 3:0:0   -t 3:8300 $DISK    # /
   sudo udevadm settle                       # wait for the -partN links
   sudo mkfs.vfat -F32 -n BOOT ${DISK}-part1
   sudo mkfs.ext4 -L nixos  ${DISK}-part2
   sudo mkfs.ext4 -L data  ${DISK}-part3
   sudo mount ${DISK}-part2 /mnt
   sudo mkdir -p /mnt/boot
   sudo mount ${DISK}-part1 /mnt/boot
   sudo mkdir -p /mnt/data
   sudo mount ${DISK}-part3 /mnt/data
   ```
   Do NOT import the pools and do NOT mount /mnt/raid or /mnt/ssd — that is
   phase 2, after the machine boots on its own.
4. Generate the hardware config:
   `sudo nixos-generate-config --root /mnt`, then copy
   `/mnt/etc/nixos/hardware-configuration.nix` over the placeholder at
   `hosts/server/hardware-configuration.nix` in your copy of the repo (put
   it at e.g. `/tmp/nix-config`). It should contain `/`, `/boot` and
   `/mnt/data`; delete anything it wrote for the data pools — the host
   module owns those.
5. Optional but saves a round trip — create the SSH host key now, so sops
   works from the very first boot (NixOS keeps an existing key):
   ```bash
   sudo mkdir -p /mnt/etc/ssh
   sudo ssh-keygen -t ed25519 -N "" -C server -f /mnt/etc/ssh/ssh_host_ed25519_key
   nix-shell -p ssh-to-age --run 'ssh-to-age < /mnt/etc/ssh/ssh_host_ed25519_key.pub'
   ```
   Put that age key in `.sops.yaml` as `&server`, then re-encrypt so the new
   key becomes a recipient:
   ```bash
   nix-shell -p sops --run 'sops updatekeys secrets/secrets.yaml'
   ```
   `updatekeys` **decrypts** the file before re-encrypting it, so it only
   runs where a key that is already a recipient exists — your personal age
   key, `~/.config/sops/age/keys.txt` (`&mig`). The live installer has no
   such key unless you copied it onto the USB stick; point sops at it with
   `export SOPS_AGE_KEY_FILE=/path/to/keys.txt` (the installer's `$HOME` is
   not yours). If you didn't bring it, do this on the laptop instead and
   copy the repo to the server again.

   Skipping step 5 entirely is fine — it just moves the same work to first
   boot (step 3 below).
6. **`git add -A`** in `/tmp/nix-config`. Flakes ignore untracked files, so
   a freshly copied `hardware-configuration.nix` is invisible until git
   knows about it — you would silently install the placeholder.
7. Install — the first full build happens here; if it errors, fix and
   re-run (nothing is written to disk until the build succeeds):
   ```bash
   sudo nixos-install --flake /tmp/nix-config#server
   ```
   (If the installer complains flakes aren't enabled, prefix with
   `NIX_CONFIG="experimental-features = nix-command flakes"`.)
   Set the root password when prompted, unplug the USB stick, reboot.

### First boot (console)

The machine comes up bare: ssh, tailscale, and nothing else.

1. Log in as mig (password `change-me` from core), `passwd` to set a real
   one, then remove `initialPassword` from `modules/core/default.nix` on the
   next rebuild. Your SSH public key is already deployed by core, so key
   login should work immediately.
2. `systemctl --failed` should be empty. The pools aren't imported, but
   `noauto` on their mounts keeps `zfs-import-raid` / `zfs-import-ssd` off
   the boot path entirely, so nothing should have run or failed.
3. If you skipped step 5 above, sops has no key for this host yet
   (`/run/secrets` is empty and `~/.ssh/id_ed25519` is a dangling symlink).
   Fix it now: `ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`, paste into
   `.sops.yaml` as `&server` on the laptop,
   `nix-shell -p sops --run 'sops updatekeys secrets/secrets.yaml'`, commit.
4. Get the repo onto the server, then
   `sudo nixos-rebuild switch --flake .#server`.
5. `sudo tailscale up` (then on laptop/desktop too).
6. Router: give the new NIC's MAC the 192.168.1.130 reservation. Leave the
   DHCP DNS server pointing at the old pi-hole until §4.

Stop here until the machine reboots cleanly twice.

## 3. Bring up the ZFS pools

Why the mounts carry `noauto` + `nofail`: NixOS generates a
`zfs-import-<pool>.service` from each zfs entry in `fileSystems`, and pulls
it into `zfs-import.target` → `zfs.target` → `multi-user.target` **unless
every filesystem of that pool is `noauto`**. That unit is a `Type=oneshot`
with no `TimeoutStartSec`, so a pool that can't be imported hangs the boot
forever — the console shows `A start job is running for Import ZFS pool
"raid" (… / no limit)`. `nofail` does not help; it only applies to the
`.mount` unit.

If you are stuck at that message right now: reboot, press `e` at the
systemd-boot menu and append
`systemd.mask=zfs-import-raid.service systemd.mask=zfs-import-ssd.service`
to the kernel line to get in, then rebuild with the `noauto` options.

The pools were last imported by the old server, which had a different
hostid, so the first import needs `-f`. That stamps them with this host's
`hostId` — after that, imports work unattended.

```bash
sudo zpool import           # confirm the names
sudo zpool import -f raid
sudo zpool import -f ssd
sudo zpool status           # no errors, all vdevs ONLINE
sudo zfs list
```

If the pools are named something other than `raid` / `ssd`, either import
under a new name (`sudo zpool import -f oldname raid`) or change `device` in
`hosts/server/default.nix` — the mount entries, and the systemd import units
generated from them, are keyed on the pool name.

Then point them at the mountpoints the config expects and mount by hand
(`noauto` means systemd won't do it for you yet):

```bash
sudo zfs set mountpoint=/mnt/raid raid
sudo zfs set mountpoint=/mnt/ssd  ssd
sudo zfs set atime=off raid
sudo zfs set atime=off ssd
sudo mount /mnt/raid
sudo mount /mnt/ssd
ls /mnt/ssd/server_config     # the old data must be there
```

Reboot and confirm the pools still import (`zpool status` — they should come
back on their own now that the hostid is stamped). Only then:

- drop `noauto` and `nofail` from both `fileSystems` entries in
  `hosts/server/default.nix`, so the pools mount at boot (from here on a
  missing pool *should* stop the boot rather than silently bring services
  up on an empty directory),
- uncomment the `services.nfs.server` block and port 2049,
- `nixos-rebuild switch`, reboot once more to prove the boot path, then
  verify the mounts from laptop/desktop.

## 4. Enable the services

Uncomment in `hosts/server/default.nix`, one rebuild at a time:

1. `caddy.nix` — needs the ACME email set and DNS/port-forwarding for
   80/443. It opens its own ports. Check `journalctl -u caddy` for issued
   certs.
2. `adguard.nix` — opens its own ports. Open `http://<server>:8053`, run
   the initial setup, import the pi-hole blocklists, add the DNS rewrite
   `*.jgelectronics.dk -> <server LAN IP>`. Only then repoint the router's
   DHCP DNS at the new server.
3. `stepping-stone` — the docker stacks. They need their firewall ports
   uncommented (docker publishes past the nixos firewall anyway, so this is
   mostly bookkeeping). The secrets must already decrypt; if a stack started
   before that, `sudo systemctl restart 'stack-*'`.

Verify: every app answers on its usual URL, kopia UI works.

## 5. Migrations, one at a time

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

All paths are in the `let` block at the top of `modules/services/arr.nix` —
config dirs are NixOS options, sabnzbd's download dirs are declared in
`settings.misc`, but sonarr/radarr **root folders live in their sqlite db**
and can only be changed in the UI.

```bash
docker compose -f /etc/stepping-stone/arr/compose.yml down   # frees 8989/7878/8181
for a in sonarr radarr sabnzbd; do
  sudo rsync -a /mnt/ssd/server_config/$a/ /var/lib/$a/
done
# the container kept MediaCover on the raid pool, outside /config
sudo rsync -a /mnt/raid/bulkdata/sonarr/MediaCover/ /var/lib/sonarr/MediaCover/
sudo rsync -a /mnt/raid/bulkdata/radarr/MediaCover/ /var/lib/radarr/MediaCover/
sudo chown -R sonarr:media /var/lib/sonarr
sudo chown -R radarr:media /var/lib/radarr
sudo chown -R sabnzbd:media /var/lib/sabnzbd
```

Enable `arr.nix`, `nixos-rebuild switch`, then fix the paths that were
container paths:

- sonarr → Settings → Media Management → Root Folders: `/series` becomes
  `/mnt/raid/media/series` (and Series → Mass Editor → Root Folder to move
  every series onto it). Radarr: `/movies` → `/mnt/raid/media/movies`.
- sonarr/radarr → Settings → Download Clients → sabnzbd: remove the remote
  path mapping if one exists; sabnzbd now reports real host paths.
- sabnzbd's own `download_dir`/`complete_dir` are set by nix, so its ini is
  already correct on first start.

umask no longer needs setting in the UI — the units run with `UMask=0002`
and sabnzbd with `permissions = "0775"`.

Then: delete the stack, remove 8989/7878/8181 from the firewall (tailnet
access remains).

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
