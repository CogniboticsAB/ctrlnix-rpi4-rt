# ctrlnix-rt

PREEMPT_RT kernel 6.18 LTS and EtherCAT IGH master for NixOS — supports both `aarch64-linux` (Raspberry Pi 4) and `x86_64-linux`.

Linux 6.18+ has PREEMPT_RT merged into mainline — no external patch needed.

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

          # aarch64 (RPi4):
          boot.kernelPackages      = pkgs.linuxPackages-rt-rpi4;
          boot.extraModulePackages = [ pkgs.ethercat-kmod-rpi4 ];
          environment.systemPackages = [ pkgs.ethercat-userspace-rpi4 ];

          # x86_64:
          # boot.kernelPackages      = pkgs.linuxPackages-rt-x86;
          # boot.extraModulePackages = [ pkgs.ethercat-kmod-x86 ];
          # environment.systemPackages = [ pkgs.ethercat-userspace-x86 ];
        }
      ];
    };
  };
}
```

## Packages

| Package | aarch64 name | x86_64 name | Description |
|---------|-------------|-------------|-------------|
| RT Kernel | `linuxPackages-rt-rpi4` | `linuxPackages-rt-x86` | Linux 6.18 LTS with `PREEMPT_RT` |
| EtherCAT kmod | `ethercat-kmod-rpi4` | `ethercat-kmod-x86` | IgH EtherCAT master 1.6.9 kernel module |
| EtherCAT userspace | `ethercat-userspace-rpi4` | `ethercat-userspace-x86` | IgH EtherCAT userspace tools (`ethercat` CLI) |

## Kernel configuration

Applied to both architectures:

- `PREEMPT_RT=yes` — full real-time preemption
- `PREEMPT=no` — disabled (replaced by PREEMPT_RT)
- `PREEMPT_VOLUNTARY=no` — disabled (replaced by PREEMPT_RT)
- `RCU_BOOST=yes` — RCU priority boosting for RT tasks

## EtherCAT

IgH EtherCAT master 1.6.9 built against the RT kernel. Set your NIC MAC address in your host configuration:

```nix
boot.extraModprobeConfig = ''
  options ec_master main_devices=XX:XX:XX:XX:XX:XX
'';
boot.kernelModules = [ "ec_master" "ec_generic" ];
```
