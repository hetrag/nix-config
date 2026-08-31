{ ... }:

{
  hsnw_index = {
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
}