# Restic replaces kopia: one scheduled job snapshotting everything that must
# survive losing a pool. The repo lives on the ssd pool while the bulk of
# the sources (postgres dumps, media) live on the raid, so the two copies
# share no disk. Offsite is an rclone mirror of the repo folder to Google
# Drive, chained after each successful backup — cheaper than a second restic
# repo (no re-read of the NAS, prune stays local and fast), at the cost of
# being a mirror rather than an independent repo.
{ config, pkgs, ... }:

let
  paths = [
    "/mnt/raid/nas"
    "/var/lib/sonarr/Backups"
    "/var/lib/radarr/.config/radarr/Backups"
    "/mnt/raid/backups/postgresql"
    # when immich lands, add "/mnt/raid/media/immich" — the job runs as
    # root, so it can read the 0700 library
  ];
in {
  sops.secrets."restic/password" = { };
  sops.secrets."restic/rclone_conf" = { };

  services.restic.backups.server = {
    passwordFile = config.sops.secrets."restic/password".path;
    repository = "/mnt/ssd/restic";
    initialize = true;
    inherit paths;
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

  # runs via OnSuccess on the backup unit, so it never overlaps a write and
  # skips the sync when the backup failed. --backup-dir keeps anything prune
  # deleted (or a wiped repo would overwrite) under restic-trash/<date> —
  # empty that folder occasionally.
  systemd.services.restic-gdrive-sync = {
    description = "Mirror restic repo to Google Drive";
    environment.RCLONE_CONFIG = config.sops.secrets."restic/rclone_conf".path;
    path = [ pkgs.rclone ];
    serviceConfig.Type = "oneshot";
    script = ''
      rclone sync /mnt/ssd/restic gdrive:restic --backup-dir gdrive:restic-trash/$(date +%F)
    '';
  };
  systemd.services."restic-backups-server".unitConfig.OnSuccess =
    "restic-gdrive-sync.service";
}
