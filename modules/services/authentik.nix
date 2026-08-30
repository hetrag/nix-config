# Authentik, native via github:nix-community/authentik-nix (imported in
# flake.nix). It configures its own local postgres and redis/valkey.
# Fronted by caddy at auth.jgelectronics.dk -> 127.0.0.1:9000.
#
# After first boot: visit https://auth.jgelectronics.dk/if/flow/initial-setup/
# to create the admin user, then create OAuth2 clients for immich and
# open-webui (see their modules for the wiring).
{ config, ... }:

{
  services.authentik = {
    enable = true;
    # TLS/entrypoint is caddy's job, not the nginx module's
    nginx.enable = false;
    environmentFile = config.sops.templates."authentik-env".path;
    settings = {
      disable_startup_analytics = true;
      avatars = "initials";
      # email = { # TODO when SMTP is wanted
      #   host = "smtp.example.com";
      #   port = 587;
      #   use_tls = true;
      #   username = "authentik@example.com";
      #   from = "authentik@example.com";
      # };
    };
  };

  sops.secrets."authentik/secret_key" = { };
  sops.templates."authentik-env".content = ''
    AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik/secret_key"}
    # AUTHENTIK_EMAIL__PASSWORD=... # TODO together with the email settings
  '';

  # 9000 (http) and 9443 (https) stay firewalled off — only caddy talks to
  # authentik on localhost.
}
