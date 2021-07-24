{ lib, config, pkgs, ... }: with lib; let
  cfg = config.services.wireplumber;
  arc = import ../../canon.nix { inherit pkgs; };
  migrateAlsa = throw "TODO"; #  config.services.pipewire.mediaSession.alsa-monitor)
  pipewireModuleType = types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      arguments = mkOption {
        type = pipewireModuleArgs;
        default = { };
      };
      flags = {
        ifexists = mkOption {
          type = types.bool;
          default = false;
        };
        nofail = mkOption {
          type = types.bool;
          default = false;
        };
      };
      out = {
        context = mkOption {
          type = types.attrs;
          internal = true;
        };
        component = mkOption {
          type = types.attrs;
          internal = true;
        };
      };
    };
    config.out = {
      context = {
        inherit (config) name;
        args = config.arguments;
        flags = mapAttrsToList (k: _: k) (
          filterAttrs (_: flag: flag) config.flags
        );
      };
      component = {
        inherit (config) name;
        type = "pw_module";
        # TODO: assert that args and flags are empty because they are not supported
      };
    };
  });
  pipewireModuleTypeSloppy = with types; coercedTo str (name: { inherit name; }) pipewireModuleType;
  commandType = types.submodule ({ options, config, ... }: {
    options = {
      add-spa-lib = {
        namePattern = mkOption {
          type = types.str;
        };
        libraryName = mkOption {
          type = types.str;
        };
      };
      load-pipewire-module = {
        moduleName = mkOption {
          type = types.str;
        };
        arguments = mkOption {
          type = pipewireModuleArgs;
          default = { };
        };
      };
      load-module = {
        abi = mkOption {
          type = types.enum [ "C" ];
          default = "C";
        };
        moduleName = mkOption {
          type = types.str;
        };
        parameters = mkOption {
          type = types.attrsOf gvariantType;
          default = { };
        };
        out.parametersBlock = mkOption {
          type = types.str;
          internal = true;
        };
      };

      out = {
        type = mkOption {
          type = types.enum [ "add-spa-lib" "load-pipewire-module" "load-module" ];
        };
        directive = mkOption {
          type = types.str;
        };
      };
    };

    config = {
      type = mkMerge [
        (mkIf options.add-spa-lib.libraryName.isDefined "add-spa-lib")
        (mkIf options.load-pipewire-module.moduleName.isDefined "load-pipewire-module")
        (mkIf options.load-module.moduleName.isDefined "load-module")
      ];
      out.directive = {
        add-spa-lib = concatStringsSep " " [ config.add-spa-lib.namePattern config.add-spa-lib.libraryName ];
        load-pipewire-module = concatStringsSep " " (
          singleton config.load-pipewire-module.moduleName
          ++ mapAttrsToList (_: arg: arg.out.directive) config.load-pipewire-module.arguments
        );
        load-module = concatStringsSep " " (
          [ config.load-module.abi config.load-module.moduleName ]
          ++ optional (config.load-module.parameters != { }) config.load-module.out.parametersBlock
        );
      }.${config.out.type};
      load-module = {
        out.parametersBlock = gvariant (
          mapAttrs' (_: param: nameValuePair param.name param.value) config.load-module.parameters
        );
      };
    };
  });
  pipewireContextType = with types; oneOf [ bool int str (attrsOf pipewireContextType) (listOf pipewireContextType) ];
in {
  options.services.wireplumber = {
    enable = mkEnableOption "wireplumber";
    package = mkOption {
      type = types.package;
      default = pkgs.wireplumber or arc.packages.wireplumber;
      defaultText = "pkgs.wireplumber";
    };
    logLevel = mkOption {
      type = types.int;
      default = 2;
    };
    access = {
      enable = mkEnableOption "default access module" // { default = true; };
      enableFlatpakPortal = mkOption {
        type = types.bool;
        default = true;
      };
      rules = mkOption {
        type = with types; listOf attrs;
      };
    };
    defaults = {
      enable = mkEnableOption "Track/store/restore user choices about devices";
      persistent = mkEnableOption "store preferences to the file system and restore them at startup" // {
        default = true;
      };
      properties = mkOption {
        type = with types; attrs;
      };
    };
    alsa = {
      enable = mkEnableOption "Load alsa device monitor";
      migrateMediaSession = mkOption {
        type = types.bool;
        default = false;
      };
      reserve = {
        enable = mkEnableOption "Device reservation" // { default = true; };
        priority = mkOption {
          type = types.int;
          default = -20;
        };
        name = mkOption {
          type = types.str;
          default = "WirePlumber";
        };
      };
      properties = mkOption {
        type = with types; attrsOf types.unspecified;
        default = { };
      };
      rules = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
      };
    };
    v4l2 = {
      enable = mkEnableOption "Load v4l2 device monitor";
    };
    bluez = {
      enable = mkEnableOption "Load bluetooth device monitor";
    };
    intended-roles.enable = mkEnableOption ''
      Link nodes by stream role and device intended role
    '' // { default = true; };
    suspend-node.enable = mkEnableOption ''
      Automatically suspends idle nodes after 3 seconds
    '' // { default = true; };
    device-activation.enable = mkEnableOption ''
      Automatically sets device profiles to 'On'
    '' // { default = true; };
    ipc.enable = mkEnableOption ''
      Listens for events comming from the wpipc library
    '';
    pipewire = {
      modules = mkOption {
        type = types.listOf pipewireModuleTypeSloppy;
      };
      spaLibs = mkOption {
        type = with types; attrsOf str;
      };
      rt = {
        enable = mkEnableOption "rt";
        nice = mkOption {
          type = types.int;
          default = -11;
        };
        priority = mkOption {
          type = types.int;
          default = 88;
        };
        limit = {
          soft = mkOption {
            type = types.int;
            default = 2000000;
          };
          hard = mkOption {
            type = types.int;
            default = cfg.pipewire.rt.limit.soft;
          };
        };
      };
    };
    modules = mkOption {
      type = types.listOf wireplumberModuleType;
    };
    startup = mkOption {
      # TODO: is all of this outdated info?
      type = types.listOf commandType;
      default = [ ];
    };
    config = mkOption {
      type = with types; attrsOf (either (attrsOf pipewireContextType) (listOf pipewireContextType));
    };
    extraConfig = mkOption {
      type = types.lines;
      default = "";
    };
    configScript = mkOption {
      type = types.lines;
    };
    configFile = mkOption {
      type = types.path;
    };
    moduleDir = mkOption {
      type = types.path;
    };
  };

  config = {
    services.wireplumber = {
      configScript = mkAfter cfg.extraConfig;
      configFile = pkgs.writeText "wireplumber.conf" cfg.configScript;
      pipewire = {
        modules = mkMerge [
          (mkIf cfg.pipewire.rt.enable (mkBefore [
            {
              name = "libpipewire-module-rtkit";
              args = let inherit (cfg.pipewire) rt; in {
                "nice.level" = rt.nice;
                "rt.prio" = rt.priority;
                "rt.time.soft" = rt.limit.soft;
                "rt.time.hard" = rt.limit.hard;
              };
            }
          ]))
          (mkBefore [
            { name = "libpipewire-module-protocol-native"; }
            { name = "libpipewire-module-client-node"; }
            { name = "libpipewire-module-client-device"; }
            { name = "libpipewire-module-adapter"; }
            { name = "libpipewire-module-metadata"; }
          ])
          [
            { name = "libpipewire-module-session-manager"; }
          ]
        ];
        spaLibs = mapAttrs (_: mkOptionDefault) {
          "api.alsa.*" = "alsa/libspa-alsa";
          "api.bluez5.*" = "bluez5/libspa-bluez5";
          "api.v4l2.*" = "v4l2/libspa-v4l2";
          "api.libcamera.*" = "libcamera/libspa-libcamera";
          "audio.convert.*" = "audioconvert/libspa-audioconvert";
          "support.*" = "support/libspa-support";
        };
      };
      access.rules = [
        {
          matches = [
            [
              [ "pipewire.access" "=" "flatpak" ]
            ]
          ];
          default_permissions = "rx";
        }
      ];
      defaults.properties = mapAttrs (_: mkOptionDefault) {
        "use-persistent-storage" = cfg.defaults.persistent;
      };
      alsa = {
        properties = mapAttrs (_: mkOptionDefault) {
          "alsa.reserve" = cfg.alsa.reserve.enable;
          "alsa.reserve.priority" = cfg.alsa.reserve.priority;
          "alsa.reserve.application-name" = cfg.alsa.reserve.name;
        };
        rules = mkMerge [
          [ {
            matches = [
              [
                [ "device.name" "matches" "alsa_card.*" ]
              ]
            ];
            apply_properties = mapAttrs (_: mkOptionDefault) {
              "api.alsa.use-acp" = true;
              "api.acp.auto-profile" = false;
              "api.acp.auto-port" = false;
            };
          } ]
          (mkIf cfg.alsa.migrateMediaSession migrateAlsa)
        ];
      };
      components = let
        access = singleton {
          name = "access/access-default.lua";
          type = "script/lua";
          args = {
            rules = cfg.access.rules;
          };
        } ++ optionals cfg.access.enableFlatpakPortal [
          { name = "libwireplumber-module-portal-permissionstore"; type = "module"; }
          { name = "libwireplumber-module-portal"; type = "module"; }
        ];
        defaults = [
          { name = "libwireplumber-module-default-nodes"; type = "module"; args = cfg.defaults.properties; }
          { name = "default-routes.lua"; type = "script/lua"; args = cfg.defaults.properties; }
        ] ++ optionals cfg.defaults.persistent [
          { name = "libwireplumber-module-default-profile"; type = "module"; }
          { name = "restore-stream.lua"; type = "script/lua"; }
        ];
        prelude =
          optional cfg.lua.enable { name = "libwireplumber-module-lua-scripting"; type = "module"; }
          ++ singleton { name = "libwireplumber-module-metadata"; type = "module"; };
        alsa =
          optional cfg.alsa.reserve.enable { name = "libwireplumber-module-reserve-device"; type = "module"; }
          ++ { name = "monitor-alsa"; type = "script/lua"; args = {
            properties = cfg.alsa.properties;
            rules = cfg.alsa.rules;
          }; };
        v4l2 = throw "TODO";
        bluez = throw "TODO";
      in mkMerge [
        (mkBefore (
          prelude
          ++ optionals cfg.access.enable access
        ))
        (
          optionals cfg.alsa.enable alsa
          ++ optionals cfg.v4l2.enable v4l2
          ++ optionals cfg.bluez.enable bluez
        )
        (mkAfter (
          optionals cfg.defaults.enable defaults
          ++ optional cfg.intended-roles.enable {
            name = "intended-roles.lua"; type = "script/lua";
          }
          ++ optional cfg.suspend-node.enable {
            name = "suspend-node.lua"; type = "script/lua";
          }
          ++ optional cfg.device-activation.enable {
            name = "libwireplumber-module-device-activation"; type = "module";
          }
          ++ optional cfg.ipc.enable {
            name = "libwireplumber-module-wpipc"; type = "module";
            args.path = "wpipc";
          }
        ))
      ];
      config = {
        "context.properties" = mapAttrs (_: mkOptionDefault) {
          "log.level" = cfg.logLevel;
          "wireplumber.script-engine" = "lua-scripting";
        };
        "context.spa-libs" = mapAttrs (_: mkOptionDefault) cfg.pipewire.spaLibs;
        "context.modules" = map (mod: mod.out.context) cfg.pipewire.modules;
        "wireplumber.components" = mkMerge [
          (mkBefore [
            { name = "libwireplumber-module-lua-scripting"; type = "module"; }
            { name = "libwireplumber-module-metadata"; type = "module"; }
            { name = "access/access-default.lua"; type = "script/lua"; args = {
              rules = cfg.defaultAccessRules;
            }; }
          ])
          (mkIf cfg.enableFlatpakPortal (mkBefore [
            {name = "libwireplumber-module-portal-permissionstore"; type = "module"; }
            {name = "libwireplumber-module-portal"; type = "module"; }
          ]))
          [
            { name = "xxx"; type = "script/lua"; args = {
            }; }
            #{ name = "main.lua"; type = "config/lua"; }
            #{ name = "policy.lua"; type = "config/lua"; }
            #{ name = "bluetooth.lua"; type = "config/lua"; }
          ]
        ];
      };
      /*startup = mkMerge [
        (mkBefore [
          { add-spa-lib = {
            namePattern = "api.alsa.*";
            libraryName = "alsa/libspa-alsa";
          }; }
        ])
        [
        #{ load-pipewire-module = {
        #  moduleName = "module-monitor";
        #  arguments = {
        #    factory = "api.alsa.enum.udev";
        #    flags = [ "use-adapter" ];
        #  };
        #}; }
        { load-module = {
          moduleName = "libwireplumber-module-monitor";
          parameters = {
            factory = "api.alsa.enum.udev";
            flags = [ "use-adapter" ];
          };
        }; }
        { load-pipewire-module = {
          moduleName = "libpipewire-module-config-endpoint";
          arguments = {
          };
        }; }
      ] ];*/
    };
    environment.systemPackages = mkIf cfg.enable [ cfg.package ];
    systemd.user.services.wireplumber = mkIf cfg.enable {
      environment = {
        WIREPLUMBER_CONFIG_FILE = cfg.configFile;
        WIREPLUMBER_MODULE_DIR = cfg.moduleDir;
        # SPA_PLUGIN_DIR, PIPEWIRE_MODULE_DIR ?
      };
    };
  };
}
