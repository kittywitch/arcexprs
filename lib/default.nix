self: super: let
  callLibs = file: import file { inherit self super; };
in with self; {
  scope = callLibs ./scope.nix;
  inherit (scope) nixPathImport nixPathScopedImport nixPathList;

  # is a string a path?
  # (note: true for paths and strings that look like paths)
  isPath = types.path.check;

  # Coerce into a Path type if appropriate, otherwise copy contents to store first
  # (this really should just be a module data type, like either path lines)
  asPath = name: contentsOrPath:
    # undocumented behaviour (https://github.com/NixOS/nix/issues/200)
    if isDerivation contentsOrPath || (isStorePath contentsOrPath && !builtins.pathExists contentsOrPath) then contentsOrPath
    else if isStorePath contentsOrPath then builtins.storePath contentsOrPath # nix will re-copy a store path without this, and that's silly
    else if isPath contentsOrPath then /. + contentsOrPath
    else builtins.toFile name contentsOrPath;

  # Return path-like strings as-is, otherwise copy contents to store first
  # (asPath except no requirement on being a path type or found in the store)
  asFile = name: contentsOrPath:
    if isPath contentsOrPath then contentsOrPath
    else builtins.toFile name contentsOrPath;

  # named // operator
  update = a: b: a // b;

  bitShl = sh: v:
    assert isInt sh; assert isInt v;
    if sh == 0 then v
    else bitShl (sh - 1) (v * 2);

  bitShr = sh: v:
    assert isInt sh; assert isInt v;
    if sh == 0 then v
    else bitShr (sh - 1) (v / 2);

  # attrset to list of { name, value } pairs
  attrNameValues = mapAttrsToList nameValuePair;

  mapListToAttrs = f: l: listToAttrs (map f l);

  # merge list of attrsets left to right
  foldAttrList = foldl update {};

  # recursive attrset merge
  foldAttrListRecursive = foldl updateRecursive {};

  moduleValue = config: builtins.removeAttrs config ["_module"]; # wh-what was this for..?

  # copy function signature
  copyFunctionArgs = src: dst: setFunctionArgs dst (functionArgs src);

  # non-overridable callPackageWith
  callWith = autoArgs: fn: args: let
    f = if isFunction fn then fn else import fn;
  in f (callWithArgs autoArgs f args);

  # intersection of autoArgs and args for fn
  callWithArgs = autoArgs: fn: args: let
    f = if isFunction fn then fn else import fn;
    auto = builtins.intersectAttrs (functionArgs f) autoArgs;
  in auto // args;

  /* I don't really know what I want out of this okay damn
  # callPackgeWith for functions that return functions
  callFunctionWith = autoArgs: fn: args: let
    f = if isFunction fn then fn else import fn;
    auto = autoArgs // args;
    fargs = callWithArgs auto f { };
    f' = makeOverridable f fargs;
    f'' = args: callFunctionWith args f' { };
  in if isFunction f'
    then makeOverridable f'' auto;
    else f';

  #callFunctionWith for attrsets
  callFunctionsWith = autoArgs: fn: args: let
    res = callPackageWith autoArgs fn args;
  in if isFunction fn || (!isAttrs fn && isPath fn) then
    (if isFunction res
      then callFunctionWith autoArgs res args
      else res)
    else if isAttrs fn then
      mapAttrs (_: p: callFunctionWith autoArgs p args) fn
    else builtins.trace fn (throw "expected package function");*/

  isRust2018 = rustPlatform: rustVersionAtLeast rustPlatform "1.31";
  rustVersionAtLeast = rustPlatform: versionAtLeast rustPlatform.rust.rustc.version;

  # add persistent passthru attributes that can refer to the derivation
  drvPassthru = fn: drv: let
    passthru = {
      override = f: drvPassthru fn (drv.override f);
      overrideDerivation = f: drvPassthru fn (drv.overrideDerivation f);
      overrideAttrs = f: drvPassthru fn (drv.overrideAttrs f);
    } // (fn drv);
  in if isFunction drv # allow chaining with mkDerivation
    then attrs: drvPassthru fn (drv attrs)
    else self.extendDerivation true passthru drv;

  # add a .exec attribute to a derivation with the absolute path of its main binary
  drvExec = relPath: drvPassthru (drv: {
    exec =
      if relPath == "" then "${drv}"
      else "${drv}/${relPath}${drv.stdenv.hostPlatform.extensions.executable}";
  });
}
