# Network-wide DNS filtering, replacing pi-hole. The web UI runs on
# http://<server>:8053 (the port pi-hole's web UI used).
{ ... }:

{
  services.adguardhome = {
    enable = true;
    host = "0.0.0.0";
    port = 8053;
    # First configuration happens through the web UI; once it is settled,
    # consider locking it down declaratively (mutableSettings = false) —
    # see MIGRATION.md.
    mutableSettings = true;
    settings = {
      dns = {
        upstream_dns = [
          "9.9.9.9#dns.quad9.net"
          "149.112.112.112#dns.quad9.net"
          # Uncomment the following to use a local DNS service (e.g. Unbound)
          # Additionally replace the address & port as needed
          # "127.0.0.1:5335"
        ];
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;

        parental_enabled = false;  # Parental control-based DNS requests filtering.
        safe_search = {
          enabled = false;  # Enforcing "Safe search" option for search engines, when possible.
        };
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
