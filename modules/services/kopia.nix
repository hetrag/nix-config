{ config, pkgs, ... }:

{
  systemd.services.kopia-server = {
    description = "kopia repository server (web UI)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "root"; # must be able to read every backup source
      EnvironmentFile = [ config.sops.templates."kopia-env".path ];
      ExecStart = ''
        ${pkgs.kopia}/bin/kopia \
          --config-file /mnt/ssd/server_config/kopia/repository.config \
          server start \
          --address 0.0.0.0:51515 \
          --tls-generate-cert \
          --server-username admin \
          --server-password-file ${config.sops.secrets."kopia/server_password".path}
      '';
      Restart = "on-failure";
    };
  };

  sops.secrets."kopia/server_password" = { };
  sops.secrets."kopia/repo_password" = { };
  sops.templates."kopia-env".content = ''
    KOPIA_REPO_PASSWORD=${config.sops.placeholder."kopia/repo_password"}
    KOPIA_SERVER_PASSWORD=${config.sops.placeholder."kopia/server_password"}
  '';
}
