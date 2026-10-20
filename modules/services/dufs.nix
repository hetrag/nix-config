# Dufs file server for /mnt/raid/share.
# Listens on loopback only (127.0.0.1:8082) — authentication and group
# authorization are enforced in front of it by Caddy + Authentik's
# forward_auth proxy provider at https://files.jgelectronics.dk.
{ pkgs, ... }:

let
  shareDir = "/mnt/raid/share";
  dufsStrataSrc = pkgs.fetchzip {
    url = "https://github.com/mcking-07/dufs-strata/releases/download/v1.0.0/dufs-strata.zip";
    hash = "sha256-D25lQeFKHXsEfFJE/32ZoFSuqTdHNdKM3Vww+IVLRmQ=";
  };
  # dufs-strata gates upload/delete buttons on `!!p.user` (expecting dufs's
  # built-in `-a` basic auth). Since Authentik handles auth in front of dufs,
  # enable upload/delete based on dufs's allow_* flags and hide the Sign In button.
  dufsStrataTheme = pkgs.runCommand "dufs-strata-theme" { } ''
    cp -r ${dufsStrataSrc} $out
    chmod -R u+w $out
    substituteInPlace $out/index.html \
      --replace-fail 'let re=!!p.user,ie=re&&p.allow_upload,ae=re&&p.allow_delete' 'let re=true,ie=p.allow_upload,ae=p.allow_delete' \
      --replace-fail '(0,H.jsxs)(`button`,{onClick:s,className:N(P.outline,P.icon,`sm:w-auto sm:px-3`),"aria-label":`sign in`,children:[(0,H.jsx)(wr,{className:`w-3.5 h-3.5`}),(0,H.jsx)(`span`,{className:`max-sm:hidden`,children:`sign in`})]})' 'null'
  '';
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
      ExecStart = "${pkgs.dufs}/bin/dufs --bind 127.0.0.1 --port 8082 --allow-all --hidden '.*' --assets ${dufsStrataTheme} ${shareDir}";
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
