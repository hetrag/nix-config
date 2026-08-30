# DRAFT (last migration step) — replaces the kopia stepping-stone container,
# and with it the --insecure / --without-password /
# --allow-extremely-dangerous-unauthenticated-server-on-the-network flags:
# the native unit serves real TLS and proper authentication, and only the
# tailnet can reach it (the firewall blocks 51515 from the LAN if you remove
# it from hosts/server's allowedTCPPorts).
#
# Not imported yet. Before enabling: check `kopia server start --help` flags
# against the packaged version, then delete kopia.yml + its stack entry from
# modules/services/stepping-stone.
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
    # opens the repository — same value the container uses today
    KOPIA_PASSWORD=${config.sops.placeholder."kopia/repo_password"}
  '';
}
