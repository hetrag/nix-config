{ pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable Flakes and new CLI tools permanently
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  users.users."mig" = {
    isNormalUser = true;
    description = "mig";
    extraGroups = [
      "wheel"           # Enable sudo
      "networkmanager"  # Allow managing network connections
      "video"           # Access to video devices/brightness
      "audio"           # Direct audio access if needed
      "render"
    ];

  # System-wide packages
  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    btop
  ];
  
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
 


  # Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
