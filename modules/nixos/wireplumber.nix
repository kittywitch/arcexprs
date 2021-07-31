{ lib, config, pkgs, ... }: with lib; let
  cfg = config.services.wireplumber;
  arc = import ../../canon.nix { inherit pkgs; };
  toLuaExpr = lib.lua.toLuaExpr or arc.lib.lua.toLuaExpr;
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
        lua = mkOption {
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
        # TODO: assert that args and flags are empty because they are not yet supported
      };
      lua = {
        # TODO: assert flags are empty
        "[1]" = config.name;
        type = "pw_module";
        args = config.arguments;
      };
    };
  });
  wireplumberModuleType = types.submodule ({ config, ... }: {
    options = {
      name = mkOption {
        type = types.str;
      };
      arguments = mkOption {
        type = pipewireModuleArgs;
        default = { };
      };
      type = mkOption {
        type = types.enum [ "module" "script/lua" "config/lua" ];
        default = "module";
      };
      out = {
        component = mkOption {
          type = types.attrs;
          internal = true;
        };
        lua = mkOption {
          type = types.attrs;
          internal = true;
        };
      };
    };
    config.out = {
      component = {
        inherit (config) name type;
        # TODO: assert that args are empty because they are not yet supported
      };
      lua = {
        "[1]" = config.name;
        inherit type;
        args = config.arguments;
      };
    };
  });
  pipewireModuleTypeSloppy = with types; coercedTo str (name: { inherit name; }) pipewireModuleType;
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
    lua = {
      enable = mkEnableOption "lua scripting engine" // { default = true; };
      componentsConfig = mkOption {
        type = types.attrs;
        internal = true;
      };
      componentsConfigFile = mkOption {
        type = types.path;
        internal = true;
      };
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
    components = mkOption {
      type = types.listOf wireplumberModuleType;
    };
    config = mkOption {
      type = with types; attrsOf (either (attrsOf pipewireContextType) (listOf pipewireContextType));
    };
    configFile = mkOption {
      type = types.path;
      internal = true;
    };
    moduleDir = mkOption {
      type = types.path;
    };
  };

  config = {
    services.wireplumber = {
      configFile = pkgs.writeText "wireplumber.conf" (toJSON cfg.config);
      lua = {
        componentsConfig = listToAttrs (imap (i: comp: nameValuePair "${fixedWidthNumber 3 i}${comp.name}" comp.out.lua) cfg.components);
        componentsConfigFile = pkgs.writeText "wireplumber.lua" ''
          components = ${toLuaExpr cfg.lua.componentsConfig}
        '';
      };
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
          optionals cfg.access.enable access
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
        "context.properties" = {
          "log.level" = mkOptionDefault cfg.logLevel;
          "wireplumber.script-engine" = mkIf cfg.lua.enable (mkOptionDefault "lua-scripting");
        };
        "context.spa-libs" = mapAttrs (_: mkOptionDefault) cfg.pipewire.spaLibs;
        "context.modules" = map (mod: mod.out.context) cfg.pipewire.modules;
        "wireplumber.components" = let
          prelude =
            optional cfg.lua.enable { name = "libwireplumber-module-lua-scripting"; type = "module"; }
            ++ singleton { name = "libwireplumber-module-metadata"; type = "module"; };
        in mkMerge [
          (mkBefore prelude)
          # XXX: until wp spa json supports "args", module configuration must be done via lua syntax
          # see https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/45
          [ { name = "${cfg.lua.componentsConfig}"; type = "config/lua"; } ]
        ];
      };
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
