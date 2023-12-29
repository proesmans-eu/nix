{ modulesPath, config, lib, pkgs, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./immich.nix
  ];
  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    # change this to your ssh key
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUcKAUBNwlSZYiFc3xmCSSmdb6613MRQN+xq+CjZR7H bert@B-PC"
  ];

  # TODO; Get the F away from fail2ban
  services.fail2ban = {
    enable = true;
    bantime-increment.enable = true;
    jails = {
      nginx-bad-request.settings = {
        enabled = true;
        backend = "polling";
        journalmatch = "";
      };

      nginx-bad-auth = {
        filter."Definition" = {
          failregex = "^<HOST> .* \"(GET|POST) .*auth\/login.*\" 401";
        };
        settings = {
	  port    = "http,https";
	  logpath = "%(nginx_access_log)s";
          backend = "polling";
	  journalmatch = "";
        };
      };
    };
  };

  system.stateVersion = "23.11";
}
