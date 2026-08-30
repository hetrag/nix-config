# Network-wide DNS filtering, replacing pi-hole. The web UI runs on
# http://<server>:8053 (the port pi-hole's web UI used).
{ ... }:

{
  services.adguardhome = {
    enable = true;
    openFirewall = true; # DNS (53) + web UI
    # First configuration happens through the web UI; once it is settled,
    # consider locking it down declaratively (mutableSettings = false) —
    # see MIGRATION.md.
    mutableSettings = true;
    settings = {
      http = {
        address = "0.0.0.0:8053";
      };
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
      };
    };
  };

  # adguard-home binds :53; keep systemd-resolved's stub listener out of its way
  services.resolved.settings.Resolve.DNSStubListener = "no";

  # TODO after first boot, in the AdGuard UI — this replaces what pi-hole
  # did for the LAN:
  #   Filters -> DNS rewrites: "*.jgelectronics.dk" -> <server LAN IP>
  # Without it, LAN clients need hairpin NAT on the router to reach caddy.
}
