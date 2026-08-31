# Native open-webui behind caddy (127.0.0.1:3000). Data moves from
# /mnt/ssd/server_config/open-webui to /var/lib/open-webui (MIGRATION.md).
#
# OIDC via authentik. The application/provider pair on the authentik side is
# created by hand (admin UI): slug "open-webui", confidential OAuth2 client
# with the same client ID, strict redirect URI
# https://openwebui.jgelectronics.dk/oauth/oidc/callback. Its client secret
# lives in sops (open-webui/oauth_client_secret) and reaches the service via
# the template below. OPENID_PROVIDER_URL must be the full discovery URL —
# open-webui 0.11 takes the .well-known document path, not the issuer base.
{ config, ... }:

{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    environment = {
      ENABLE_AUTOCOMPLETE_GENERATION = "false";
      ENABLE_FOLLOW_UP_GENERATION = "false";
      ENABLE_TITLE_GENERATION = "false";
      # OIDC — matches the provider created in authentik
      OAUTH_CLIENT_ID = "open-webui";
      OAUTH_PROVIDER_NAME = "authentik";
      OPENID_PROVIDER_URL = "https://auth.jgelectronics.dk/application/o/open-webui/.well-known/openid-configuration";
      OPENID_REDIRECT_URI = "https://openwebui.jgelectronics.dk/oauth/oidc/callback";
      # The nixpkgs module defaults this to http://localhost:3000, which
      # breaks OIDC redirect/logout — override with the public URL.
      WEBUI_URL = "https://openwebui.jgelectronics.dk";
      # Create users on first login and merge them with local accounts that
      # share the authentik email (picks up the migrated admin account).
      # Local password login stays enabled as fallback until SSO is proven.
      ENABLE_OAUTH_SIGNUP = "true";
      OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "true";
    };
    environmentFile = config.sops.templates."open-webui-env".path;
  };

  sops.secrets."open-webui/oauth_client_secret" = { };
  sops.templates."open-webui-env".content = ''
    OAUTH_CLIENT_SECRET=${config.sops.placeholder."open-webui/oauth_client_secret"}
  '';
}
