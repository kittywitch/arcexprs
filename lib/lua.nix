{ lib }: with lib; let
  toLuaList = list: "{" + concatMapStringsSep ", " toLuaExpr list + "}";
  toLuaTable = attrs: "{" + concatStringsSep ", " (mapAttrsToList (k: v: "${k}=${toLuaExpr v}") attrs) + "}";
  toLuaString = str: ''"'' + replaceStrings [ ''"'' "\\" "\n" ] [ ''\"'' ''\\'' ''\n'' ] str + ''"'';
  toLuaExpr = value:
    if isString value then toLuaString value
    else if isList value then toLuaList value
    else if isAttrs value then toLuaTable value
    else toString value;
in {
  inherit toLuaExpr;
}
