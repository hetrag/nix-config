# Native vikunja on the shared native postgres (modules/services/postgres)
# over its unix socket — peer auth, so no database password is involved.
{ config, lib, ... }:

{
  services.vikunja = {
    enable = true;
    frontendScheme = "https";
    frontendHostname = "vikunja.jgelectronics.dk";
    port = 3456;
    database = {
      type = "postgres";
      host = "/run/postgresql";
      user = "vikunja";
      database = "vikunja";
    };
    environmentFiles = [ config.sops.templates."vikunja-env".path ];
  };

  # vikunja runs as a DynamicUser, so it cannot own files. Give it read
  # access to the secret through the media group (members: mig + services).
  systemd.services.vikunja.serviceConfig.SupplementaryGroups = [ "media" ];

  sops.secrets."vikunja/service_secret" = { };
  sops.templates."vikunja-env" = {
    owner = "root";
    group = "media";
    mode = "0440";
    content = ''
      VIKUNJA_SERVICE_SECRET=${config.sops.placeholder."vikunja/service_secret"}
    '';
  };
}
