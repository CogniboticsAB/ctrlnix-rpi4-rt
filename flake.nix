{
  description = "PREEMPT_RT kernel 6.18 and EtherCAT IGH master for NixOS (aarch64 + x86_64)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: let
    lib = nixpkgs.lib;

    # ─── Kernel config (shared between architectures) ─────────────────
    rtKernelConfig = with lib.kernel; {
      PREEMPT_RT        = yes;
      PREEMPT           = lib.mkForce no;
      PREEMPT_VOLUNTARY = lib.mkForce no;
      RCU_BOOST         = yes;
    };

    # ─── EtherCAT source (shared) ─────────────────────────────────────
    ethercatSrc = {
      owner = "etherlab.org";
      repo  = "ethercat";
      rev   = "b709e58147e65b5e3251b45f48c01ef33cc7366f";
      hash  = "sha256-Msx0i1SAwlSMD3+vjGRNe36Yx9qdUYokVekGytZptqk=";
    };

    # ─── Build EtherCAT kmod against a given kernel package set ───────
    mkEthercatKmod = linuxPackages: pkgs:
      linuxPackages.callPackage
        ({ stdenv, fetchFromGitLab, kernel, automake, autoconf, libtool, pkgconf }:
        stdenv.mkDerivation {
          pname   = "ethercat-kmod";
          version = "1.6.9";
          src = fetchFromGitLab ethercatSrc;
          nativeBuildInputs = [ automake autoconf libtool pkgconf ]
            ++ kernel.moduleBuildDependencies;
          preConfigure = "bash ./bootstrap";
          configureFlags = [
            "--enable-generic"
            "--with-linux-dir=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
          ];
          buildPhase = ''
            make
            make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
              M=$(pwd) modules
          '';
          installPhase = ''
            mkdir -p $out
            make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" \
              M=$(pwd) INSTALL_MOD_PATH=$out modules_install
          '';
        }) { fetchFromGitLab = pkgs.fetchFromGitLab; };

    # ─── Build EtherCAT userspace tools against a given kernel ────────
    mkEthercatUserspace = linuxPackages: pkgs:
      pkgs.stdenv.mkDerivation {
        pname   = "ethercat-userspace";
        version = "1.6.9";
        src = pkgs.fetchFromGitLab ethercatSrc;
        nativeBuildInputs = with pkgs; [ automake autoconf libtool pkgconf ];
        preConfigure = "bash ./bootstrap";
        configureFlags = [
          "--enable-generic"
          "--with-linux-dir=${linuxPackages.kernel.dev}/lib/modules/${linuxPackages.kernel.modDirVersion}/build"
        ];
        installPhase = "make install prefix=$out";
      };

    # ─── aarch64 packages ─────────────────────────────────────────────
    pkgs-aarch64 = nixpkgs.legacyPackages."aarch64-linux";

    linuxPackages-rt-rpi4 = pkgs-aarch64.linuxPackages_rpi4.extend (self: super: {
      kernel = super.kernel.override {
        structuredExtraConfig = rtKernelConfig;
      };
    });

    # ─── x86_64 packages ──────────────────────────────────────────────
    pkgs-x86 = nixpkgs.legacyPackages."x86_64-linux";

    linuxPackages-rt-x86 = pkgs-x86.linuxPackages_6_18.extend (self: super: {
      kernel = super.kernel.override {
        structuredExtraConfig = rtKernelConfig;
      };
    });

  in {
    # ─── Packages ─────────────────────────────────────────────────────
    packages."aarch64-linux" = rec {
      kernel             = linuxPackages-rt-rpi4.kernel;
      ethercat-kmod      = mkEthercatKmod linuxPackages-rt-rpi4 pkgs-aarch64;
      ethercat-userspace = mkEthercatUserspace linuxPackages-rt-rpi4 pkgs-aarch64;
      default            = kernel;
    };

    packages."x86_64-linux" = rec {
      kernel             = linuxPackages-rt-x86.kernel;
      ethercat-kmod      = mkEthercatKmod linuxPackages-rt-x86 pkgs-x86;
      ethercat-userspace = mkEthercatUserspace linuxPackages-rt-x86 pkgs-x86;
      default            = kernel;
    };

    # ─── Overlays ─────────────────────────────────────────────────────
    # Usage in your flake.nix:
    #
    #   inputs.rt.url = "github:YOUR_ORG/ctrlnix-rt";
    #
    #   nixpkgs.overlays = [ inputs.rt.overlays.default ];
    #
    #   # aarch64 (RPi4):
    #   boot.kernelPackages      = pkgs.linuxPackages-rt-rpi4;
    #   boot.extraModulePackages = [ pkgs.ethercat-kmod-rpi4 ];
    #
    #   # x86_64:
    #   boot.kernelPackages      = pkgs.linuxPackages-rt-x86;
    #   boot.extraModulePackages = [ pkgs.ethercat-kmod-x86 ];
    #
    overlays.default = final: prev: {
      linuxPackages-rt-rpi4   = linuxPackages-rt-rpi4;
      ethercat-kmod-rpi4      = mkEthercatKmod linuxPackages-rt-rpi4 prev;
      ethercat-userspace-rpi4 = mkEthercatUserspace linuxPackages-rt-rpi4 prev;

      linuxPackages-rt-x86    = linuxPackages-rt-x86;
      ethercat-kmod-x86       = mkEthercatKmod linuxPackages-rt-x86 prev;
      ethercat-userspace-x86  = mkEthercatUserspace linuxPackages-rt-x86 prev;
    };
  };
}