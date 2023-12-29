# nix

Checkout the [flake.nix](flake.nix) for more details.

## Erebos

Use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) from a machine with nix installed to replace a working system with a custom config.

`nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> root@<ip address>`


The configuration can be tested beforehand using `--vm-test`

`nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> --vm-test`

## Gaia

Use nixos-rebuild to update the system configuration remotely (from a machine with nix installed).

`nixos-rebuild switch --use-substituters --flake <URL to your flake> --target-host "root@<ip address>"`


The configuration can be **live** tested using `test`

`nixos-rebuild test --use-substituters --flake <URL to your flake> --target-host "root@<ip address>"`

