# ctrlnix-rt

PREEMPT_RT kernels and EtherCAT IGH master for NixOS — supports `aarch64-linux` (Raspberry Pi 4) and `x86_64-linux`.

Linux 6.12+ has PREEMPT_RT merged into mainline — no external patch needed.

## Binary Cache

Pre-built binaries are available via Cachix — no need to compile yourself:

```nix
nix.settings = {
  substituters = [
    "https://cache.nixos.org"
    "https://cognibotics.cachix.org"
  ];
  trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "cognibotics.cachix.org-1:qcwFFasLKhSxQEKC5tgb/0+HIFlie3kc+PpPQSxlBv4="
  ];
};
```

## Usage

Add this flake as an input to your NixOS configuration:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    rt.url = "github:YOUR_ORG/ctrlnix-rt";
  };

  outputs = { self, nixpkgs, rt }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux"; # or "x86_64-linux"
      modules = [
        ./configuration.nix
        {
          nixpkgs.overlays = [ rt.overlays.default ];

          # aarch64 (RPi4, 6.12):
          boot.kernelPackages      = pkgs.linuxPackages-rt-rpi4-612;
          boot.extraModulePackages = [ pkgs.ethercat-kmod-rpi4-612 ];
          environment.systemPackages = [ pkgs.ethercat-userspace-rpi4-612 ];

          # x86_64 (6.12):
          # boot.kernelPackages      = pkgs.linuxPackages-rt-x86-612;
          # boot.extraModulePackages = [ pkgs.ethercat-kmod-x86-612 ];
          # environment.systemPackages = [ pkgs.ethercat-userspace-x86-612 ];

          # x86_64 (6.18):
          # boot.kernelPackages      = pkgs.linuxPackages-rt-x86-618;
          # boot.extraModulePackages = [ pkgs.ethercat-kmod-x86-618 ];
          # environment.systemPackages = [ pkgs.ethercat-userspace-x86-618 ];
        }
      ];
    };
  };
}
```

## Packages

| Package | Description |
|---------|-------------|
| `linuxPackages-rt-rpi4-612` | RPi4 kernel 6.12 with `PREEMPT_RT` |
| `ethercat-kmod-rpi4-612` | IgH EtherCAT master 1.6.9 kernel module (RPi4, 6.12) |
| `ethercat-userspace-rpi4-612` | IgH EtherCAT userspace tools (RPi4, 6.12) |
| `linuxPackages-rt-x86-612` | x86_64 kernel 6.12 with `PREEMPT_RT` |
| `ethercat-kmod-x86-612` | IgH EtherCAT master 1.6.9 kernel module (x86, 6.12) |
| `ethercat-userspace-x86-612` | IgH EtherCAT userspace tools (x86, 6.12) |
| `linuxPackages-rt-x86-618` | x86_64 kernel 6.18 with `PREEMPT_RT` |
| `ethercat-kmod-x86-618` | IgH EtherCAT master 1.6.9 kernel module (x86, 6.18) |
| `ethercat-userspace-x86-618` | IgH EtherCAT userspace tools (x86, 6.18) |

## Kernel configuration

Applied to all three kernels:

- `PREEMPT_RT=yes` — full real-time preemption
- `PREEMPT=no` — disabled (replaced by PREEMPT_RT)
- `RCU_BOOST=yes` — RCU priority boosting for RT tasks

`PREEMPT_VOLUNTARY` is intentionally not set: it exists in 6.12 but was removed in 6.18, so omitting it keeps the config compatible with both versions.

## EtherCAT

IgH EtherCAT master 1.6.9 built against the RT kernel. Set your NIC MAC address in your host configuration:

```nix
boot.extraModprobeConfig = ''
  options ec_master main_devices=XX:XX:XX:XX:XX:XX
'';
boot.kernelModules = [ "ec_master" "ec_generic" ];
```
