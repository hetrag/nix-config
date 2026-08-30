# Native open-webui behind caddy (127.0.0.1:3000). Data moves from
# /mnt/ssd/server_config/open-webui to /var/lib/open-webui (MIGRATION.md).
#
# OIDC: once authentik is up, create an OAuth2 provider/client for open-webui
# and fill in the OAUTH_* variables below — secrets go in the sops template,
# never in this file.
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
      # TODO with authentik:
      # WEBUI_AUTH = "True";
      # OAUTH_CLIENT_ID = "open-webui";
      # OAUTH_CLIENT_NAME = "authentik";
      # OPENID_PROVIDER_URL = "https://auth.jgelectronics.dk/application/o/authorize/";
      # OAUTH_SCOPES = "openid email profile";
    };
    environmentFile = config.sops.templates."open-webui-env".path;
  };

  # Empty until the authentik migration adds:
  #   OAUTH_CLIENT_SECRET=<from sops placeholder>
  sops.templates."open-webui-env".content = "";
}
