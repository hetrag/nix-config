{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable Flakes and new CLI tools permanently
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Shared group for everything that reads/writes the media libraries on the
  # NAS disks. gid 2000 matches the NFS export's anongid (hosts/server).
  users.groups.media = { gid = 2000; };

  users.users."mig" = {
    isNormalUser = true;
    description = "mig";
    uid = 1000; # matches the NFS export's anonuid
    # Bootstrap-only: log in once on the console, set a real password, put
    # your SSH public key in openssh.authorizedKeys.keys below, then REMOVE
    # initialPassword (see MIGRATION.md, first boot).
    initialPassword = "change-me";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIO0eF5Cq8LZr6k5wCzNncsiuZ6ckOLzJOifICO7oPv4 mig"
    ];
    extraGroups = [
      "wheel"           # Enable sudo
      "networkmanager"  # Allow managing network connections
      "media"           # Media libraries on /mnt/raid
      "video"           # Access to video devices/brightness
      "audio"           # Direct audio access if needed
      "render"
    ];
  };

  # System-wide packages
  environment.systemPackages = with pkgs; [
    git
    gh
    wget
    curl
    btop
    vim
    claude-code
    # antigravity-cli  # unstable-only (not in nixos-26.05); re-add via an
    #                   # unstable input or when 26.05 picks it up
    nodejs
    sops        # Edit encrypted secrets
    age         # Personal encryption key for sops
    ssh-to-age  # Convert SSH host keys to age keys for .sops.yaml
  ];

  # SSH access, keys only — the host key also serves as sops-nix's decryption key
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Tailnet on every host: admin access to the servers without exposing
  # anything publicly. First run needs a manual `sudo tailscale up`.
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  # NAS data. The server hosts these disks locally and re-exports them over
  # NFS (see the mkForce overrides in hosts/server/default.nix); every other
  # host mounts them as an NFS client.
  fileSystems."/mnt/raid" = {
    device = "192.168.1.130:/mnt/raid";
    fsType = "nfs4";
    options = [
      "defaults"
      "user"
      "exec"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };

  fileSystems."/mnt/ssd" = {
    device = "192.168.1.130:/mnt/ssd";
    fsType = "nfs4";
    options = [
      "defaults"
      "user"
      "exec"
      "x-systemd.automount"
      "noauto"
      "x-systemd.idle-timeout=600"
    ];
  };

  # Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  #solves steam download speedcxd

  services.resolved = {
  enable = true;
  extraConfig = ''
    DNSStubListener=no
  '';
  };
}
