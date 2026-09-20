# Native immich. Media stays at the exact path the container uses today
# (/mnt/raid/media/immich); the module brings its own postgres (with
# vectorchord) and redis over unix sockets — no passwords. ML stays enabled
# (default). Backup: postgresqlBackup (postgres.nix) dumps the DB at 02:00,
# restic at 03:30 snapshots media + dumps (it runs as root, so the 0700
# library is readable). Dump/restore + ownership steps: MIGRATION.md.
{ config, ... }:

{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/raid/media/immich";
    settings = {
      server.externalDomain = "https://immich.jgelectronics.dk";
      oauth = {
        enabled = true;
        issuerUrl = "https://auth.jgelectronics.dk/application/o/immich/";
        clientId = "immich";
        clientSecret._secret = config.sops.secrets."immich/oauth_client_secret".path;
        scope = "openid email profile";
      };
    };
  };

  # The module only chmods/chowns an *existing* mediaLocation (tmpfiles "e");
  # on a bare restore the directory would be missing and the server flaps.
  systemd.tmpfiles.rules = [
    "d ${config.services.immich.mediaLocation} 0700 immich immich -"
  ];

  sops.secrets."immich/oauth_client_secret" = { }; # TODO with authentik
}
