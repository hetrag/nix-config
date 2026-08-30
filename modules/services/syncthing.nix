# Native syncthing. The existing config directory moves over as-is
# (/mnt/ssd/server_config/syncthing), so folders and devices keep being
# managed in the web UI for now (override* = false). Going fully declarative
# later is just listing them under settings.folders / settings.devices.
{ ... }:

{
  services.syncthing = {
    enable = true;
    configDir = "/mnt/ssd/server_config/syncthing";
    dataDir = "/mnt/raid"; # shared folder paths live under it
    user = "syncthing";
    group = "media"; # read/write the shared folders
    overrideDevices = false;
    overrideFolders = false;
    openFirewall = true; # 22000 tcp/udp + 21027 udp
    settings.gui = {
      # LAN is blocked by the firewall, so the GUI ends up tailnet-only
      address = "0.0.0.0:8384";
    };
  };
}
