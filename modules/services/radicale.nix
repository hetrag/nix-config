{ config, pkgs, ... }:

{
  services.radicale = {
    enable = true;
    settings = {
      server.hosts = [ "127.0.0.1:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/run/radicale/users";
        htpasswd_encryption = "bcrypt";
      };
      storage.filesystem_folder = "/var/lib/radicale/collections";
    };
  };

  systemd.services.radicale.serviceConfig.SupplementaryGroups = [ "media" ];

  sops.secrets."radicale/user" = { };
  sops.secrets."radicale/password" = { };

  systemd.services.radicale.preStart = ''
    USER=$(cat ${config.sops.secrets."radicale/user".path})
    PASS=$(cat ${config.sops.secrets."radicale/password".path})

    # Generate bcrypt htpasswd file dynamically
    ${pkgs.apacheHttpd}/bin/htpasswd -b -B -c /run/radicale/users "$USER" "$PASS"
    chmod 0440 /run/radicale/users
    chown root:media /run/radicale/users
  '';
}