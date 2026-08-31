{ lib, ... }:

{
  services.qdrant = {
    enable = true;
    settings = {
      hnsw_index = {
        on_disk = true;
      };
      service = {
        grpc_port = 6334;
        host = "0.0.0.0";
        http_port = 6333;
      };
      storage = {
        snapshots_path = "/data/databases/qdrant/snapshots";
        storage_path = "/data/databases/qdrant/storage";
      };
      telemetry_disabled = true;
    };
  };

  # The upstream module runs qdrant with DynamicUser=yes, which implies
  # ProtectSystem=strict - only /var/lib/qdrant would be writable and there is
  # no stable user to chown /data to. Run as a static user instead (same setup
  # as the arr stack), so the data dir can live directly on /data.
  users.users.qdrant = {
    isSystemUser = true;
    group = "qdrant";
  };
  users.groups.qdrant = { };

  systemd.services.qdrant = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "qdrant";
      Group = "qdrant";
    };
    unitConfig.RequiresMountsFor = [ "/data/databases/qdrant" ];
  };

  systemd.tmpfiles.rules = [
    "d /data/databases/qdrant 0750 qdrant qdrant -"
  ];
}