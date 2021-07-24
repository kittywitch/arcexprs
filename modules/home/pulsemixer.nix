{ config, lib, pkgs, ... }: with lib; let
  cfg = config.programs.pulsemixer;
in {
  options.programs.pulsemixer = {
    enable = mkEnableOption "pulsemixer";

    package = mkOption {
      type = types.package;
      default = pkgs.pulsemixer;
      defaultText = "pkgs.pulsemixer";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
    };

    # TODO: https://github.com/GeorgeFilipkin/pulsemixer#configuration

    configIni = mkOption {
      type = types.lines;
    };
  };

  config = {
    home.packages = mkIf cfg.enable [ cfg.package ];
    xdg.configFile."pulsemixer.cfg" = mkIf cfg.enable {
      text = cfg.configIni;
    };
    programs.pulsemixer = {
      configIni = ""; # generate from cfg!
    };
  };
}
