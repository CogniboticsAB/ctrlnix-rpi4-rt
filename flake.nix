{
  description = "PREEMPT_RT kernel and EtherCAT IGH master for Raspberry Pi 4 on NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: let
    system = "aarch64-linux";
    pkgs   = nixpkgs.legacyPackages.${system};
    lib    = nixpkgs.lib;

    # ─── RT Kernel ───────────────────────────────────────────────────
    # Linux 6.12+ has PREEMPT_RT merged into mainline - no external patch needed
    linuxPackages-rt-rpi4 = pkgs.linuxPackages_rpi4.extend (self: super: {
      kernel = super.kernel.override {
        structuredExtraConfig = with lib.kernel; {
          PREEMPT_RT        = yes;
          PREEMPT           = lib.mkForce no;
          PREEMPT_VOLUNTARY = lib.mkForce no;
          RCU_BOOST         = yes;
        };
      };
    });

    # ─── EtherCAT IGH kernel module ──────────────────────────────────
    ethercat-kmod = linuxPackages-rt-rpi4.callPackage
      ({ stdenv, fetchFromGitLab, kernel, automake, autoconf, libtool, pkgconf }:
      stdenv.mkDerivation {
        pname   = "ethercat-kmod";
        version = "1.6.9";
        src = fetchFromGitLab {
          owner = "etherlab.org";
          repo  = "ethercat";
          rev   = "b709e58147e65b5e3251b45f48c01ef33cc7366f";
          hash  = "sha256-Msx0i1SAwlSMD3+vjGRNe36Yx9qdUYokVekGytZptqk=";
        };
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

    # ─── EtherCAT userspace tools ────────────────────────────────────
    ethercat-userspace = pkgs.stdenv.mkDerivation {
      pname   = "ethercat-userspace";
      version = "1.6.9";
      src = pkgs.fetchFromGitLab {
        owner = "etherlab.org";
        repo  = "ethercat";
        rev   = "b709e58147e65b5e3251b45f48c01ef33cc7366f";
        hash  = "sha256-Msx0i1SAwlSMD3+vjGRNe36Yx9qdUYokVekGytZptqk=";
      };
      nativeBuildInputs = with pkgs; [ automake autoconf libtool pkgconf ];
      preConfigure = "bash ./bootstrap";
      configureFlags = [
        "--enable-generic"
        "--with-linux-dir=${linuxPackages-rt-rpi4.kernel.dev}/lib/modules/${linuxPackages-rt-rpi4.kernel.modDirVersion}/build"
      ];
      installPhase = "make install prefix=$out";
    };

  in {
    # ─── Packages ────────────────────────────────────────────────────
    packages.${system} = {
      kernel             = linuxPackages-rt-rpi4.kernel;
      ethercat-kmod      = ethercat-kmod;
      ethercat-userspace = ethercat-userspace;
      default            = linuxPackages-rt-rpi4.kernel;
    };

    # ─── Overlay for use in other flakes ─────────────────────────────
    # Usage in your flake.nix:
    #
    #   inputs.rpi4-rt.url = "github:YOUR_ORG/nixos-rpi4-rt";
    #
    #   nixpkgs.overlays = [ inputs.rpi4-rt.overlays.default ];
    #   boot.kernelPackages = pkgs.linuxPackages-rt-rpi4;
    #   boot.extraModulePackages = [ pkgs.ethercat-kmod-rpi4 ];
    #
    overlays.default = final: prev: {
      linuxPackages-rt-rpi4  = linuxPackages-rt-rpi4;
      ethercat-kmod-rpi4     = ethercat-kmod;
      ethercat-userspace-rpi4 = ethercat-userspace;
    };
  };
}
