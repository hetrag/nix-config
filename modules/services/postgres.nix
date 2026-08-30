# Single native postgres for everything that migrates off the stepping stone.
# Vikunja's database is created here; authentik and immich enable their own
# databases through their modules. services.postgresqlBackup replaces the
# per-stack backup sidecars — one dump job for all databases, written to the
# raid (kopia then picks the directory up for the offsite copy).
{ ... }:

{
  services.postgresql = {
    enable = true;
    ensureDatabases = [ "vikunja" ];
    ensureUsers = [
      {
        name = "vikunja";
        ensureDBOwnership = true;
      }
    ];
  };

  services.postgresqlBackup = {
    enable = true;
    location = "/mnt/raid/backups/postgresql";
    startAt = "*-*-* 02:00:00";
    # backs up all databases by default
  };
}
