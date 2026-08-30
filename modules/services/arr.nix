# Sonarr / radarr / sabnzbd, native. Config dirs move from
# /mnt/ssd/server_config/<name> to /var/lib/<name> (see MIGRATION.md).
# They run as their own users with group "media" — replacing the old
# PUID/PGID trick. After migration, set umask to 002 in each app's UI
# (Settings -> Media Management) so files land group-writable.
{ ... }:

{
  services.sonarr = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  services.sabnzbd = {
    enable = true;
    group = "media";
    openFirewall = true;
    allowConfigWrite = true;
    settings = {
      misc = {
        host = "0.0.0.0";
      };
    };
  };
}
