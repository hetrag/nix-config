# Stepping stone: the docker stacks from the old server, running unchanged
# under systemd units (one per stack, so they can be migrated and deleted one
# at a time). Compose files in this directory are copied verbatim from
# docker_configs/ — except that hardcoded secrets were replaced by env
# variables (vikunja, kopia).
#
# Deliberately NOT carried over from the old setup:
#   nextcloud-aio, portainer, nginx-proxy-manager (caddy), pi-hole (adguard)
#
# The shared env file is rendered from sops; values marked CHANGE-ME must be
# filled in secrets/secrets.yaml before first boot (see MIGRATION.md).
{ config, lib, pkgs, ... }:

let
  envFile = config.sops.templates."stepping-stone-env".path;

  stacks = [
    "immich"
    "vikunja"
    "arr" # sonarr + radarr + sabnzbd
    "syncthing"
    "open-webui"
    "qdrant" # permanent home — never migrates to native (no module)
    "kopia"
  ];

  mkStackUnit = name: {
    description = "docker compose stack: ${name}";
    after = [
      "network-online.target"
      "docker.service"
      "sops-nix.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ docker docker-compose ];
    # the compose files reference an external network (kept verbatim)
    preStart = ''
      docker network create lab-net 2>/dev/null || true
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker compose \
        --project-name ${name} \
        --env-file ${envFile} \
        -f /etc/stepping-stone/${name}/compose.yml \
        up -d --remove-orphans
    '';
  };
in
{
  virtualisation.docker.enable = true;

  environment.etc = builtins.listToAttrs (
    map
      (name: {
        name = "stepping-stone/${name}/compose.yml";
        value = { source = ./. + "/${name}.yml"; };
      })
      stacks
  );

  systemd.services = builtins.listToAttrs (
    map
      (name: {
        name = "stack-${name}";
        value = mkStackUnit name;
      })
      stacks
  );

  # Values for these live in secrets/secrets.yaml under a `stepping-stone:`
  # map — see MIGRATION.md ("values marked CHANGE-ME") for what goes in them.
  sops.secrets."stepping-stone/db_password" = { };
  sops.secrets."stepping-stone/vikunja_service_secret" = { };
  sops.secrets."stepping-stone/kopia_repo_password" = { };

  sops.templates."stepping-stone-env" = {
    content = ''
      # Shared layout — identical paths to the old docker setup
      PUID=1000
      PGID=1000
      TZ=Europe/Copenhagen
      CONF_SSD=/mnt/ssd/server_config
      MEDIA_HDD=/mnt/raid/media
      DATA_SSD=/mnt/ssd
      DATA_HDD=/mnt/raid
      DATABASES_HDD=/mnt/raid/databases
      NETWORK_NAME=lab-net

      # The containerized databases keep the passwords their volumes were
      # initialized with: copy the CURRENT values from the old server's
      # portainer env here (see MIGRATION.md). Fresh passwords are only
      # introduced when the databases move to native postgres.
      DB_USERNAME=postgres
      DB_PASSWORD=${config.sops.placeholder."stepping-stone/db_password"}
      IMMICH_VERSION=v2
      DB_DATABASE_IMMICH_NAME=immich
      DB_DATABASE_VIKUNJA_NAME=vikunja
      VIKUNJA_SERVICE_SECRET=${config.sops.placeholder."stepping-stone/vikunja_service_secret"}
      KOPIA_PASSWORD=${config.sops.placeholder."stepping-stone/kopia_repo_password"}

      # Port registry — unchanged from the docker setup
      IMMICH_PORT=2283
      QDRANT_HTTP_PORT=6333
      QDRANT_GRPC_PORT=6334
      RADARR_PORT=7878
      SABNZBD_PORT=8181
      SONARR_PORT=8989
      OPEN_WEBUI_PORT=3000
      KOPIA_PORT=51515
      SYNCTHING_GUI_PORT=8384
      SYNCTHING_TCP_PORT=22000
      SYNCTHING_UDP_PORT=22000
      SYNCTHING_LOCAL_PORT=21027
    '';
  };
}
