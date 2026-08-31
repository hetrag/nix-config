# Public entrypoint: TLS termination for everything internet-facing,
# replacing nginx-proxy-manager. Admin UIs (adguard, arr, syncthing, kopia)
# are NOT proxied here — they stay reachable over the tailnet only
# (tailscale0 is a trusted interface in modules/core).
{ ... }:

{
  services.caddy = {
    enable = true;
    # ACME account email — TODO: set your real address
    globalConfig = ''
      email jens@gammeltoft.org
    '';
    virtualHosts = {
      # TODO: match the subdomains currently configured in
      # nginx-proxy-manager (vikunja's is known; check the others there
      # before cutting over DNS)
      "immich.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:2283
      '';
      "openwebui.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:3000
      '';
      "vikunja.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:3456
      '';
      # Goes live together with modules/services/authentik.nix
      "auth.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:9000
      '';
    };
  };

  # caddy is the only service that must be reachable from the internet
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
