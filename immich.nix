let 
  # The version of immich to deploy. Must be consistent accross all containers
  immich.version = "v1.91.4";

  # The location where your uploaded files are stored
  immich.upload_location="/store/immich";
  
  # Connection secrets. You should change these to random passwords
  immich.db_password="W!3BHBc&b3%EvYij9udi7";
in
{ pkgs, lib, ... }:

{
  # Runtime
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
    defaultNetwork.settings = {
      # Required for container networking to be able to use names.
      dns_enabled = true;
    };
  };
  virtualisation.oci-containers.backend = "podman";
  # Open firewall for DNS requests from within the containers.
  # TODO; Verify "podman+" resolved to "podman0" up to "podman9"
  # REF; https://github.com/NixOS/nixpkgs/issues/226365#issuecomment-1814296639
  networking.firewall.interfaces."podman+".allowedUDPPorts = [ 53 ];

  # Reverse proxy
  security.acme = {
    acceptTerms = true;
    defaults.email = "bproesmans@hotmail.com";
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  services.nginx = {
    enable = true;
    # Use recommended settings
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # Only allow PFS-enabled ciphers with AES256
    sslCiphers = "AES256+EECDH:AES256+EDH:!aNULL";
  };
  services.nginx.virtualHosts."www.photos.proesmans.eu" = {
    extraConfig = ''
      # Per https://immich.app/docs/administration/reverse-proxy.
      client_max_body_size 50000M;
    '';
    forceSSL = true;
    enableACME = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:2283";
      proxyWebsockets = true;
    };
  };
  # Default listener, because nginx will pick a random virtualhost if none is set.
  # Consequences are the randomly picked one is accessible even though server_name
  # doesn't match.
  services.nginx.virtualHosts."default" = {
    default = true;
    rejectSSL = true;
    locations."/" = {
      # Connection closed, no data.
      return = "444";
    };
  };

  # Containers
  virtualisation.oci-containers.containers."immich_machine_learning" = {
    image = "ghcr.io/immich-app/immich-machine-learning:${immich.version}";
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "${immich.db_password}";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "${immich.version}";
      REDIS_HOSTNAME = "immich_redis";
      UPLOAD_LOCATION = "${immich.upload_location}";
    };
    # See /var/lib/containers/storage
    volumes = [
      "model-cache:/cache:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-machine-learning"
      "--network=immich-default"
    ];
  };
  systemd.services."podman-immich_machine_learning" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich-default.service"
    ];
    requires = [
      "podman-network-immich-default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_microservices" = {
    image = "ghcr.io/immich-app/immich-server:${immich.version}";
    cmd = [ "start.sh" "microservices" ];
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "${immich.db_password}";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "${immich.version}";
      REDIS_HOSTNAME = "immich_redis";
      UPLOAD_LOCATION = "${immich.upload_location}";
    };
    volumes = [
      # "/etc/localtime:/etc/localtime:ro"
      "${immich.upload_location}:/usr/src/app/upload:rw"
    ];
    dependsOn = [
      "immich_postgres"
      "immich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-microservices"
      "--network=immich-default"
    ];
  };
  systemd.services."podman-immich_microservices" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich-default.service"
    ];
    requires = [
      "podman-network-immich-default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_postgres" = {
    image = "tensorchord/pgvecto-rs:pg14-v0.1.11@sha256:0335a1a22f8c5dd1b697f14f079934f5152eaaa216c09b61e293be285491f8ee";
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "${immich.db_password}";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "${immich.version}";
      POSTGRES_DB = "immich";
      POSTGRES_PASSWORD = "${immich.db_password}";
      POSTGRES_USER = "postgres";
      REDIS_HOSTNAME = "immich_redis";
      UPLOAD_LOCATION = "${immich.upload_location}";
    };
    # See /var/lib/containers/storage
    volumes = [
      "pgdata:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=database"
      "--network=immich-default"
    ];
  };
  systemd.services."podman-immich_postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich-default.service"
    ];
    requires = [
      "podman-network-immich-default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_redis" = {
    image = "redis:6.2-alpine@sha256:b6124ab2e45cc332e16398022a411d7e37181f21ff7874835e0180f56a09e82a";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=immich-default"
    ];
  };
  systemd.services."podman-immich_redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich-default.service"
    ];
    requires = [
      "podman-network-immich-default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };
  virtualisation.oci-containers.containers."immich_server" = {
    image = "ghcr.io/immich-app/immich-server:${immich.version}";
    cmd = [ "start.sh" "immich" ];
    environment = {
      DB_DATABASE_NAME = "immich";
      DB_HOSTNAME = "immich_postgres";
      DB_PASSWORD = "${immich.db_password}";
      DB_USERNAME = "postgres";
      IMMICH_VERSION = "${immich.version}";
      REDIS_HOSTNAME = "immich_redis";
      UPLOAD_LOCATION = "${immich.upload_location}";
    };
    volumes = [
      # "/etc/localtime:/etc/localtime:ro"
      "${immich.upload_location}:/usr/src/app/upload:rw"
    ];
    ports = [
      "2283:3001/tcp"
    ];
    dependsOn = [
      "immich_postgres"
      "immich_redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=immich-server"
      "--network=immich-default"
    ];
  };
  systemd.services."podman-immich_server" = {
    serviceConfig = {
      Restart = lib.mkOverride 500 "always";
    };
    after = [
      "podman-network-immich-default.service"
    ];
    requires = [
      "podman-network-immich-default.service"
    ];
    partOf = [
      "podman-compose-immich-root.target"
    ];
    wantedBy = [
      "podman-compose-immich-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-immich-default" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.podman}/bin/podman network rm -f immich-default";
    };
    script = ''
      podman network inspect immich-default || podman network create immich-default --opt isolate=true
    '';
    partOf = [ "podman-compose-immich-root.target" ];
    wantedBy = [ "podman-compose-immich-root.target" ];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-immich-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
