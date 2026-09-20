# Restic replaces kopia: one scheduled job snapshotting everything that must
# survive losing a pool. The repo lives on the ssd pool while the bulk of
# the sources (postgres dumps, media) live on the raid, so the two copies
# share no disk — only server_config backs up onto its own pool, same
# tradeoff the kopia draft made. Point `repository` at an SFTP/B2/rclone
# target instead when a true offsite copy is wanted.
{ config, ... }:

{
  sops.secrets."restic/password" = { };

  services.restic.backups.server = {
    passwordFile = config.sops.secrets."restic/password".path;
    repository = "/mnt/ssd/restic";
    initialize = true;

    paths = [
      "/mnt/raid/nas"
      "/var/lib/sonarr/Backups"
      "/var/lib/radarr/.config/radarr/Backups"
      "/mnt/raid/backups/postgresql"
      # when immich lands, add "/mnt/raid/media/immich" — the job runs as
      # root, so it can read the 0700 library
    ];

    # after the 02:00 postgres dump (postgres.nix)
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
    ];
  };
}
