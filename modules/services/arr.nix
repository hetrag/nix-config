# Sonarr / radarr / sabnzbd, native. Config dirs live in /var/lib/<name>
# (see MIGRATION.md), running as their own users with group "media" —
# replacing the old PUID/PGID trick.
{ config, ... }:

{
  services.sonarr = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  services.radarr = {
    enable = true;
    group = "media";
    openFirewall = true;
  };

  # The ini rendered from `settings` lands in the world-readable nix store,
  # so secrets only appear there as "@...@" patterns — the sabnzbd module's
  # preStart swaps in the contents of these files just before it starts.
  sops.secrets =
    let
      sabnzbdReadable = {
        # read by the service user during preStart (secretValues below)
        owner = "sabnzbd";
      };
    in
    {
      "sabnzbd/api_key" = sabnzbdReadable;
      "sabnzbd/nzb_key" = sabnzbdReadable;
      "sabnzbd/username" = sabnzbdReadable;
      "sabnzbd/password" = sabnzbdReadable;
      "sabnzbd/server_username" = sabnzbdReadable;
      "sabnzbd/server_password" = sabnzbdReadable;
    };

  services.sabnzbd = {
    enable = true;
    group = "media";
    openFirewall = true;

    # Rewrites /var/lib/sabnzbd/sabnzbd.ini (mode 600) on every start,
    # merging old-ini < settings < secretValues — UI changes survive only
    # for keys not declared below.
    allowConfigWrite = true;

    secretValues = {
      "@sab_api_key@" = config.sops.secrets."sabnzbd/api_key".path;
      "@sab_nzb_key@" = config.sops.secrets."sabnzbd/nzb_key".path;
      "@sab_username@" = config.sops.secrets."sabnzbd/username".path;
      "@sab_password@" = config.sops.secrets."sabnzbd/password".path;
      "@nh_username@" = config.sops.secrets."sabnzbd/server_username".path;
      "@nh_password@" = config.sops.secrets."sabnzbd/server_password".path;
    };

    settings = {
      misc = {
        # Network & access (caddy doesn't proxy this — reach it at
        # http://server:8080/sabnzbd/)
        host = "0.0.0.0";
        port = 8080;
        url_base = "/sabnzbd";
        host_whitelist = "server"; # was container hostnames
        inet_exposure = 0;

        # Credentials — patterns replaced from sops at service start
        api_key = "@sab_api_key@";
        nzb_key = "@sab_nzb_key@";
        username = "@sab_username@";
        password = "@sab_password@";

        # Storage & permissions
        download_dir = "/mnt/raid/downloads/incomplete";
        complete_dir = "/mnt/raid/downloads";
        permissions = "0775"; # group-writable for the media group
        cleanup_list = "nfo, sfv, nzb, srr, info, idx, txt, com, db, md5, par2, png, 1, jpg, jpeg, url, lnk, html, ini, bat, com, exe, scr, sample";

        # Performance & tuning
        cache_limit = "976.5 M";
        direct_unpack = 1;
        direct_unpack_threads = 2;
        num_decoders = 3;
        num_simd_decoders = 2;
        ionice = "-c3 -n10";
        nice = "-n10";
      };

      servers."NEWS.NEWSHOSTING.COM" = {
        # Key matches the section name in the migrated ini, so the rsynced
        # config merges into one server instead of a duplicate
        name = "NEWS.NEWSHOSTING.COM";
        displayname = "Newshosting";
        host = "news.newshosting.com";
        port = 563;
        connections = 7;
        ssl = true;
        username = "@nh_username@";
        password = "@nh_password@";
        pipelining_requests = 1;
      };

      categories = {
        tv = {
          name = "tv";
          dir = "tv";
          priority = -100;
          script = "Default";
        };
        audio = {
          name = "audio";
          dir = "music";
          priority = -100;
          script = "Default";
        };
        movies = {
          name = "movies";
          dir = "movies";
          priority = -100;
          script = "Default";
        };
        series = {
          name = "series";
          order = 1;
          dir = "series";
          priority = -100;
          script = "Default";
        };
      };
    };
  };

  # preStart reads the sops secret files, so wait for them to be rendered
  systemd.services.sabnzbd.after = [ "sops-nix.service" ];
}
