# Server: headless, and the NAS itself — /raid + /ssd are local zfs pools
# that this host also exports over NFS to laptop/desktop (core defines the
# client side of those mounts; here they are forced to be local).
#
# Current phase: bare boot. Services and the NFS export are commented out
# below; bring the zfs pools up first, then re-enable them one block at a
# time (see MIGRATION.md).
{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix

    # ---- Foundation, enabled from day one ----
    ../../modules/services/caddy.nix
    ../../modules/services/adguard.nix
    #../../modules/services/stepping-stone

    # ---- Native replacements, enabled one at a time as stacks migrate ----
    # (see MIGRATION.md; uncomment a line when that stack is cut over, in
    # roughly this order)
    # ../../modules/services/postgres.nix
    # ../../modules/services/syncthing.nix
    ../../modules/services/arr.nix
    ../../modules/services/qdrant.nix
    ../../modules/services/open-webui.nix
    # ../../modules/services/vikunja.nix
     ../../modules/services/authentik.nix
    # ../../modules/services/immich.nix
    # ../../modules/services/kopia.nix
    ../../modules/services/lite_llm.nix
  ];

  # Bootloader (UEFI / systemd-boot default)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "server";
  networking.useDHCP = true;

  # zfs only supports kernels a few releases behind mainline, and the module
  # build fails outright on a too-new one — so this host does not follow
  # core's linuxPackages_latest.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  # ZFS for the two NAS pools. This pulls in the zfs kernel module +
  # userspace and enables the zfs-import@pool / zfs-mount units at boot.

  boot.supportedFilesystems.zfs = true;
  boot.zfs.forceImportRoot = false; # root is ext4; only data pools here
  boot.zfs.extraPools = [ "ssd" "raid"];

  # REQUIRED by zfs: pools are stamped with the host's id at import and
  # refuse to import without it. Any unique 8 lowercase hex chars — on the
  # running server: head -c 8 /etc/machine-id
  # Set it once and NEVER change it.
  networking.hostId = "1767aa3a";


  # Pool maintenance: scrub checks pool integrity (monthly by default, every
  # imported pool). TRIM is already on by default once zfs is supported.
  services.zfs.autoScrub.enable = true;

  services.nfs.server = {
    enable = true;
    extraNfsdConfig = '''';
    mountdPort = 4000;
    statdPort = 4001;
    lockdPort = 4002;
    exports = ''
      /mnt/raid *(rw,insecure,all_squash,anonuid=1000,anongid=2000)
      /mnt/ssd  *(rw,insecure,all_squash,anonuid=1000,anongid=2000)
    '';
  };

  # Bare boot: ssh only. Uncomment a port together with the module that
  # listens on it (caddy/adguard open their own; the rest belong to the
  # docker stacks, which publish past the nixos firewall anyway).
  networking.firewall = {
    allowedTCPPorts = [
      22        # ssh
      111       # rpcbind (nfsv3)
      2049      # nfs
      4000      # mountd (nfsv3)
      4001      # statd (nfsv3)
      4002      # lockd (nfsv3)
      8053      #adguard      
      53        #adguard
      # 22000     # syncthing transfer
      # 2283      # immich
      3000      # open-webui
      5000        # lite llm
      # 3456      # vikunja
      # 51515     # kopia
      6333 
      6334 # qdrant
      7878      # radarr
      8181      # sabnzbd
      # 8384      # syncthing gui
      8989      # sonarr
    ];
    allowedUDPPorts = [
      # 21027     # syncthing local discovery
      # 22000     # syncthing transfer (quic)
      53          #adguard
      111         # rpcbind (nfsv3)
      2049        # nfs (v3 may negotiate udp)
      4000        # mountd (nfsv3)
      4001        # statd (nfsv3)
      4002        # lockd (nfsv3)
    ];
  };

  # DO NOT CHANGE: State version set at initial install
  system.stateVersion = "26.05";
}
