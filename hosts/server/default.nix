# Server: headless, and the NAS itself — /raid + /ssd are local zfs pools
# that this host also exports over NFS to laptop/desktop (core defines the
# client side of those mounts; here they are forced to be local).
{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # ---- Foundation, enabled from day one ----
    ../../modules/services/caddy.nix
    ../../modules/services/adguard.nix
    ../../modules/services/stepping-stone

    # ---- Native replacements, enabled one at a time as stacks migrate ----
    # (see MIGRATION.md; uncomment a line when that stack is cut over, in
    # roughly this order)
    # ../../modules/services/postgres.nix
    # ../../modules/services/syncthing.nix
    # ../../modules/services/arr.nix
    # ../../modules/services/open-webui.nix
    # ../../modules/services/vikunja.nix
    # ../../modules/services/authentik.nix
    # ../../modules/services/immich.nix
    # ../../modules/services/kopia.nix
  ];

  # Bootloader (UEFI / systemd-boot default)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "server";
  networking.useDHCP = true;

  # ZFS for the two NAS pools. This pulls in the zfs kernel module +
  # userspace and enables the zfs-import@pool / zfs-mount units at boot.
  # (zfs 2.4 builds fine against linuxPackages_latest in our pinned nixpkgs,
  # so core's latest kernel is OK on this host.)
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false; # root is ext4; only data pools here

  # REQUIRED by zfs: pools are stamped with the host's id at import and
  # refuse to import without it. Any unique 8 lowercase hex chars — on the
  # running server: head -c 8 /etc/machine-id
  # Set it once and NEVER change it.
  networking.hostId = "CHANGE-ME";

  # The NAS disks are local zpools on this host — override core's NFS client
  # mounts. device is the pool (or dataset) name, NOT a /dev/disk path, and
  # that dataset's mountpoint property must be set to the mount path. Once,
  # on the server (per pool):
  #   zpool import <pool>
  #   zfs set mountpoint=/mnt/raid <pool>
  #   zfs set atime=off <pool>   # zfs's equivalent of ext4's noatime (the
  #                              # property wins over mount options)
  fileSystems."/mnt/raid" = lib.mkForce {
    device = "REPLACE-ME-raid"; # pool/dataset mounted at /mnt/raid
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/mnt/ssd" = lib.mkForce {
    device = "REPLACE-ME-ssd"; # pool/dataset mounted at /mnt/ssd
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  # Pool maintenance: scrub checks pool integrity (monthly by default, every
  # imported pool). TRIM is already on by default once zfs is supported.
  services.zfs.autoScrub.enable = true;

  # Serve the same paths to laptop/desktop. Nothing zfs-specific needed here:
  # exports reference the mount paths, not the underlying fs. Keep all NFS
  # config in this block (don't also set the zfs `sharenfs` property on the
  # pools — pick one mechanism). If you ever create child datasets under
  # /mnt/raid (each is a separate mount), add `crossmnt` to that export line
  # or clients won't see them.
  # anongid=2000 = the media group from modules/core, so NFS clients get
  # group access to anything the services write as group "media".
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/raid *(rw,insecure,all_squash,anonuid=1000,anongid=2000)
      /mnt/ssd  *(rw,insecure,all_squash,anonuid=1000,anongid=2000)
    '';
  };

  # Day one: same reachability as the old docker setup (everything open to
  # the LAN). Tighten as services migrate — the end state should be caddy
  # (80/443), adguard (53) and the tailnet, plus NFS for the other hosts.
  networking.firewall = {
    allowedTCPPorts = [
      22        # ssh
      53        # adguard-home dns
      80 443    # caddy
      2049      # nfs
      22000     # syncthing transfer
      2283      # immich
      3000      # open-webui
      3456      # vikunja
      51515     # kopia
      6333 6334 # qdrant
      7878      # radarr
      8053      # adguard-home web ui
      8181      # sabnzbd
      8384      # syncthing gui
      8989      # sonarr
    ];
    allowedUDPPorts = [
      53        # adguard-home dns
      21027     # syncthing local discovery
      22000     # syncthing transfer (quic)
    ];
  };

  # DO NOT CHANGE: State version set at initial install
  system.stateVersion = "26.05";
}
