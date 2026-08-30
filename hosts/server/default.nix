# Server: headless, and the NAS itself — /raid + /ssd are local disks that
# this host also exports over NFS to laptop/desktop (core defines the client
# side of those mounts; here they are forced to be local).
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

  networking.hostName = "server";
  networking.useDHCP = true;

  # The NAS disks are local on this host — override core's NFS client mounts.
  # TODO at install: real /dev/disk/by-id/ paths + correct fsType (see the
  # note in hardware-configuration.nix about mdadm/zfs arrays).
  fileSystems."/mnt/raid" = lib.mkForce {
    device = "/dev/disk/by-id/REPLACE-ME-raid";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  fileSystems."/mnt/ssd" = lib.mkForce {
    device = "/dev/disk/by-id/REPLACE-ME-ssd";
    fsType = "ext4";
    options = [ "defaults" "noatime" ];
  };

  # Serve the same paths to laptop/desktop.
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
