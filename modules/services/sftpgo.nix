# Browser-only shared folder. Import this module in hosts/server/default.nix
# after completing setup:
# - Point files.jgelectronics.dk at Caddy.
# - In Authentik, create an OAuth2/OIDC provider and application (slug sftpgo),
#   client ID sftpgo, confidential client, scopes openid/profile/email, and
#   strict redirect URI https://files.jgelectronics.dk/web/oidc/redirect.
# - Restrict the Authentik application to the users/group allowed read/write
#   access: every successful application login grants access to the same folder.
# - Store the client secret in SOPS at sftpgo/oauth_client_secret.
{ config, lib, pkgs, ... }:

let
  domain = "files.jgelectronics.dk";
  sharedFolder = "/mnt/raid/shared";
  port = 8082;
  provisionUser = pkgs.writeShellScript "sftpgo-provision-user" ''
    set -eu
    test "$SFTPGO_LOGIND_METHOD" = IDP
    test "$SFTPGO_LOGIND_PROTOCOL" = OIDC
    printf '%s' "$SFTPGO_LOGIND_USER" | ${pkgs.jq}/bin/jq -e \
      --arg home ${lib.escapeShellArg sharedFolder} '
        .status = 1
        | .home_dir = $home
        | .filesystem = {provider: 0}
        | .virtual_folders = []
        | .permissions = {"/": [
            "list", "download", "upload", "overwrite", "delete",
            "rename", "create_dirs"
          ]}
      '
  '';
in
{
  services.sftpgo = {
    enable = true;
    group = "media";
    extraReadWriteDirs = [ sharedFolder ];
    settings = {
      common.umask = "0007";
      sftpd.bindings = [ { port = 0; } ];
      ftpd.bindings = [ { port = 0; } ];
      webdavd.bindings = [ { port = 0; } ];
      data_provider = {
        driver = "sqlite";
        name = "${config.services.sftpgo.dataDir}/sftpgo.db";
        create_default_admin = true;
        pre_login_hook = "${provisionUser}";
      };
      httpd.bindings = [
        {
          address = "127.0.0.1";
          inherit port;
          enable_web_admin = false;
          enable_web_client = true;
          enable_rest_api = false;
          enabled_login_methods = 2;
          render_openapi = false;
          proxy_allowed = [ "127.0.0.1/32" ];
          client_ip_proxy_header = "X-Forwarded-For";
          oidc = {
            client_id = "sftpgo";
            client_secret_file = config.sops.secrets."sftpgo/oauth_client_secret".path;
            config_url = "https://auth.jgelectronics.dk/application/o/sftpgo/";
            redirect_base_url = "https://${domain}";
            username_field = "sub";
            scopes = [ "openid" "profile" "email" ];
            implicit_roles = false;
          };
          security = {
            enabled = true;
            allowed_hosts = [ domain ];
            https_proxy_headers = [ { key = "X-Forwarded-Proto"; value = "https"; } ];
          };
        }
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${sharedFolder} 2770 sftpgo media -"
  ];

  systemd.services.sftpgo = {
    requires = [ "mnt-raid.mount" ];
    after = [ "mnt-raid.mount" ];
    unitConfig.RequiresMountsFor = [ sharedFolder ];
    environment.SFTPGO_DEFAULT_ADMIN_USERNAME = "bootstrap-admin";
    preStart = ''
      umask 0077
      printf 'SFTPGO_DEFAULT_ADMIN_PASSWORD=%s\n' \
        "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > /run/sftpgo/bootstrap.env
    '';
    serviceConfig = {
      UMask = lib.mkForce "0007";
      RuntimeDirectory = "sftpgo";
      RuntimeDirectoryMode = "0700";
      EnvironmentFile = "-/run/sftpgo/bootstrap.env";
    };
  };

  sops.secrets."sftpgo/oauth_client_secret".owner = config.services.sftpgo.user;

  services.caddy.virtualHosts.${domain}.extraConfig = ''
    redir / /web/client 302
    reverse_proxy 127.0.0.1:${toString port}
  '';
}