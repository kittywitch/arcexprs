{ callPackage }: let
  wrapScript = { lib, path, stdenvNoCC, makeWrapper, name, source, paths }: stdenvNoCC.mkDerivation {
    inherit source name;
    nativeBuildInputs = [makeWrapper];
    wrapperPath = lib.makeBinPath paths;
    unpackPhase = "true";
    configurePhase = "true";
    buildPhase = "true";
    installPhase = ''
      install -d $out/bin
      makeWrapper $source/bin/$name $out/bin/$name \
        --prefix PATH : $wrapperPath \
        --set-default NIX_PATH nixpkgs=${path}
    '';
  };
  nixos' = callPackage ({ nixos }: nixos { }) { };
  /*config = { lib, nix }: {
    nix.package.out = nix;
    system.nixos = {
      inherit (lib.trivial) release;
    };
  };*/
  /*nixos' = (callPackage <nixpkgs/nixos/modules/installer/tools/tools.nix> {
    config = (callPackage config { });
  }).config.system.build // {
    #manual.manpages = null;
    manual = callPackage <nixpkgs/nixos/doc/manual> {
      inherit options config version revision;
    };
  };*/
  packages = {
    nixos-enter = { lib, path, stdenvNoCC, makeWrapper, man, utillinux, coreutils }: wrapScript {
        inherit lib path stdenvNoCC makeWrapper;
        name = "nixos-enter";
        source = nixos'.nixos-enter;
        paths = [nixos'.manual.manpages man utillinux coreutils];
      };
    /*nixos-generate-config = { man }: let
      nixos' = nixos {};
    in nixos'.nixos-generate-config.overrideAttrs (old: {
      path = old.path ++ [nixos.manual.manpages man];
    });*/
    nixos-generate-config = { lib, path, stdenvNoCC, makeWrapper, man, coreutils, btrfs-progs, nixos }: wrapScript {
        inherit lib path stdenvNoCC makeWrapper;
        name = "nixos-generate-config";
        source = nixos'.nixos-generate-config;
        /*source = nixos'.nixos-generate-config.overrideAttrs (_: {
          paths = lib.makeBinPath [tools.nixos-enter];
        });*/
        paths = [nixos'.manual.manpages man coreutils btrfs-progs];
      };
    nixos-install = { lib, path, stdenvNoCC, makeWrapper, man, coreutils, nix }: wrapScript {
        inherit lib path stdenvNoCC makeWrapper;
        name = "nixos-install";
        source = nixos'.nixos-install.overrideAttrs (_: {
          paths = lib.makeBinPath [tools.nixos-enter];
        });
        paths = [nixos'.manual.manpages man coreutils nix];
      };
    nixos-option = { lib, path, stdenvNoCC, makeWrapper, man, coreutils, gnused, nix }: wrapScript {
        inherit lib path stdenvNoCC makeWrapper;
        name = "nixos-option";
        source = nixos'.nixos-option;
        paths = [nixos'.manual.manpages man coreutils gnused nix];
      };
    nixos-rebuild = { lib, path, stdenvNoCC, makeWrapper, man, coreutils, openssh, nix }: wrapScript {
        inherit lib path stdenvNoCC makeWrapper;
        name = "nixos-rebuild";
        source = nixos'.nixos-rebuild.overrideAttrs (_: { inherit nix; });
        paths = [nixos'.manual.manpages man coreutils openssh];
      };
  };
  tools = callPackage packages { };
in tools