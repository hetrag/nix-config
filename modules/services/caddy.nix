# Public entrypoint: TLS termination for everything internet-facing,
# replacing nginx-proxy-manager. Admin UIs (adguard, arr, syncthing)
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
      "immich.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:2283
      '';
      #"openwebui.jgelectronics.dk".extraConfig = ''
      #  reverse_proxy 127.0.0.1:3000
      #'';
     # "litellm.jgelectronics.dk".extraConfig = ''
     #   reverse_proxy 127.0.0.1:5000
     # '';
      "dav.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:5232
      '';
      # Goes live together with modules/services/authentik.nix
      "auth.jgelectronics.dk".extraConfig = ''
        reverse_proxy 127.0.0.1:9000
      '';
    #  "sabnzbd.jgelectronics.dk".extraConfig = ''
    #    reverse_proxy 127.0.0.1:8080
    #  '';
    };
  };

  # caddy is the only service that must be reachable from the internet
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
