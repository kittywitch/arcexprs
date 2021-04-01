self: super: let
  arc = import ../canon.nix { inherit self super; };
  filterFnAttrs = fn: args: builtins.intersectAttrs (self.lib.functionArgs fn) args;
  pythonOverrides = builtins.removeAttrs self.pythonOverrides [ "recurseForDerivations" "extend" "__unfix__" ];
in {
  arc = super.arc or { } // {
    _internal = super.arc._internal or { } // {
      overlaid'python = true;
    };
  };
  pythonOverlays = super.pythonOverlays or [ ] ++ [ (pself: psuper: builtins.mapAttrs (_: drv:
    if super.lib.isFunction drv then self.callPackage drv (filterFnAttrs drv {
      python = pself.python;
      pythonPackages = pself;
      pythonPackagesSuper = psuper;
    }) else drv
  ) pythonOverrides) ];
  pythonOverrides = super.lib.dontRecurseIntoAttrs super.pythonOverrides or { };
  pythonInterpreters = builtins.mapAttrs (pyname: py:
    if py.pkgs or null != null
    then py.override (old: {
      self = self.pythonInterpreters.${pyname};
      packageOverrides = arc.super.lib.composeManyExtensions
        (super.lib.optional (old ? packageOverrides) old.packageOverrides ++ self.pythonOverlays);
    })
    else py
  ) super.pythonInterpreters;
}