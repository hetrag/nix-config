# Native immich. Media stays at the exact path the container uses today
# (/mnt/raid/media/immich); the database moves into native postgres, which
# the module sets up itself (including the vectorchord extension) over a
# unix socket — no database password. ML stays enabled (default).
# Dump/restore + ownership steps: see MIGRATION.md.
{ ... }:

{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/raid/media/immich";
    settings = {
      server.externalDomain = "https://immich.jgelectronics.dk";
      # TODO once authentik is up — create an OAuth2 provider/client there:
      # oauth = {
      #   enabled = true;
      #   issuerUrl = "https://auth.jgelectronics.dk/application/o/immich/";
      #   clientId = "immich";
      #   clientSecret._secret = config.sops.secrets."immich/oauth_client_secret".path;
      #   scope = "openid email profile";
      # };
    };
  };

  # sops.secrets."immich/oauth_client_secret" = { }; # TODO with authentik
}
