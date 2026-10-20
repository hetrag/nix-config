# Dufs file server for /mnt/raid/share.
# Listens on loopback only (127.0.0.1:8082) — authentication and group
# authorization are enforced in front of it by Caddy + Authentik's
# forward_auth proxy provider at https://files.jgelectronics.dk.
{ pkgs, ... }:

let
  shareDir = "/mnt/raid/share";
in
{
  # Ensure the share directory exists with setgid so files created via
  # either NFS/local or dufs inherit the "media" group (gid 2000).
  systemd.tmpfiles.rules = [
    "d ${shareDir} 2770 mig media -"
  ];

  systemd.services.dufs = {
    description = "Dufs file server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = [ shareDir ];

    serviceConfig = {
      ExecStart = "${pkgs.dufs}/bin/dufs --bind 127.0.0.1 --port 8082 --allow-all ${shareDir}";
      Restart = "on-failure";

      # Run as an unprivileged dynamic user in the shared "media" group
      DynamicUser = true;
      Group = "media";
      UMask = "0007";

      # Sandboxing
      ReadWritePaths = [ shareDir ];
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectHome = true;
      ProtectSystem = "strict";
    };
  };
}
