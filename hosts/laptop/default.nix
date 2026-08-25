{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    btop
    google-chrome
  ];

  # Hostname & Networking
  networking.hostName = "laptop";
  networking.networkmanager.enable = true;

  # Bootloader (UEFI / systemd-boot default)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Primary user account
  users.users.youruser = { # Replace "youruser" with your actual username
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # DO NOT CHANGE: State version set at initial install
  system.stateVersion = "24.05"; # Match your installed version
}
