{ ... }:

{
  # TODO at install: generate with `nixos-generate-config --root /mnt` and
  # commit it as hosts/desktop/hardware-configuration.nix, then uncomment:
  # imports = [ ./hardware-configuration.nix ];

  # Hostname & Networking
  networking.hostName = "desktop";
  networking.networkmanager.enable = true;

  # Bootloader (UEFI / systemd-boot default)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # DO NOT CHANGE: State version set at initial install
  system.stateVersion = "26.05";
}
