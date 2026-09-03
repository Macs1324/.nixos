{
  config,
  lib,
  pkgs,
  ...
}: {
  # System-wide Tor client. This is *not* what Tor Browser uses — the bundle
  # ships and starts its own tor — it is here so that everything else on the
  # machine can reach the network through SOCKS5 on 127.0.0.1:9050.
  services.tor = {
    enable = true;
    client.enable = true;

    # Client only: never publish a descriptor, never carry anyone else's
    # traffic. Running a relay/exit from a home connection invites trouble.
    relay.enable = false;

    # Resolves names (including .onion) over Tor on 127.0.0.1:9053 and maps
    # onion hosts onto virtual addresses, so `torsocks curl http://…onion`
    # resolves instead of dying at DNS.
    client.dns.enable = true;

    # Installs /etc/tor/torsocks.conf pointed at the SOCKS port below.
    torsocks.enable = true;

    # Unix control socket at /run/tor/control, needed by nyx.
    controlSocket.enable = true;

    enableGeoIP = true;

    settings = {
      # A fresh circuit per destination host *and* port, so two programs
      # talking to different services never share an exit.
      SOCKSPort = lib.mkForce [
        {
          addr = "127.0.0.1";
          port = 9050;
          IsolateDestAddr = true;
          IsolateDestPort = true;
        }
      ];
    };
  };

  # Lets nyx talk to the daemon. Note this is full control-port access: a
  # process running as macs can reconfigure the local tor instance.
  users.users.macs.extraGroups = ["tor"];

  environment.systemPackages = with pkgs; [
    # The only thing to actually browse .onion sites with — it carries the
    # fingerprinting defences a normal browser behind a proxy does not.
    tor-browser

    # Wraps arbitrary CLI programs: `torsocks curl https://check.torproject.org`
    torsocks

    # Curses monitor for the daemon: circuits, bandwidth, logs.
    nyx

    # Share files or stand up a throwaway onion service.
    onionshare
    onionshare-gui
  ];
}
