# Authentik, native via github:nix-community/authentik-nix (imported in
# flake.nix). The module only adds authentik's postgres database (merged
# into the shared instance from modules/services/postgres) — no redis is
# involved, sessions have lived in the database since authentik 2025.4.
# Fronted by caddy at auth.jgelectronics.dk -> 127.0.0.1:9000.
#
# akadmin exists from the first boot (bootstrap vars in the sops template),
# so there is no internet-exposed initial-setup window. Log in at
# https://auth.jgelectronics.dk/ as akadmin with the bootstrap password
# from sops, change it, then create OAuth2 clients for immich and
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
      # Loopback-only: tailscale0 is a trusted interface (modules/core), so
      # the firewall would NOT hide authentik's [::] defaults from the
      # tailnet. (The worker is already loopback-only by module default.)
      listen = {
        http = "127.0.0.1:9000";
        https = "127.0.0.1:9443";
        metrics = "127.0.0.1:9300";
      };
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
  # Pre-creates the akadmin user — closes the initial-setup race. Applied
  # on first boot only; after changing the password in the UI this secret
  # and its template line can be dropped.
  sops.secrets."authentik/bootstrap_password" = { };
  sops.templates."authentik-env".content = ''
    AUTHENTIK_SECRET_KEY=${config.sops.placeholder."authentik/secret_key"}
    AUTHENTIK_BOOTSTRAP_PASSWORD=${config.sops.placeholder."authentik/bootstrap_password"}
    # AUTHENTIK_EMAIL__PASSWORD=... # TODO together with the email settings
  '';

  # Everything authentik listens on is pinned to loopback above — caddy is
  # its only client, no firewall holes needed.
}
