# Native immich. Media at the old container path /mnt/raid/media/immich;
# the module bundles postgres+vectorchord and redis over unix sockets (no DB
# password). Backup: postgresqlBackup dumps at 02:00, restic snapshots media
# and dumps at 03:30 as root. Migration (dump/restore/chown): MIGRATION.md.
{ config, lib, ... }:

{
  services.immich = {
    enable = true;
    port = 2283;
    host = "127.0.0.1";
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

  # Module's tmpfiles rule is "e" (adjust-if-exists) — create the dir, or a
  # bare restore crash-loops immich-server on its write probe.
  systemd.tmpfiles.rules = [
    "d ${config.services.immich.mediaLocation} 0770 immich media -"
  ];

  # Library group-readable by "media" (mig on all hosts, arr, NFS gid 2000)
  # instead of immich-only: group = "media" makes new uploads immich:media,
  # UMask 0007 keeps them g+r; the module would re-force 0700 on boot, hence
  # the mkForce. Concession: the arr stack can read the photos.
  services.immich.group = "media";
  systemd.tmpfiles.settings.immich.${config.services.immich.mediaLocation}.e.mode =
    lib.mkForce "0770";
  systemd.services.immich-server.serviceConfig.UMask = lib.mkForce "0007";

  sops.secrets."immich/oauth_client_secret" = { };
}
