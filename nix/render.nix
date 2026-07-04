# renderLab: turn an example's { topology, configs } into a self-contained
# containerlab lab directory in the Nix store.
#
#   <out>/<name>.clab.yml     rendered from the `topology` attrset via toJSON
#                             (JSON is valid YAML, and containerlab accepts it,
#                             so no YAML generator dependency is needed)
#   <out>/configs/<node>.cfg  one file per entry in the `configs` attrset
#
# This is what makes constants.nix the single source of truth: nothing in the
# rendered output is hand-typed.
pkgs:
{
  name,
  topology,
  configs,
}:
let
  lib = pkgs.lib;
  topoFile = pkgs.writeText "${name}.clab.yml" (builtins.toJSON topology);
  copyConfigs = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      fname: content:
      "install -Dm444 ${pkgs.writeText "cfg-${name}-${fname}" content} $out/configs/${fname}"
    ) configs
  );
in
pkgs.runCommand "${name}-lab" { } ''
  mkdir -p $out/configs
  install -Dm444 ${topoFile} $out/${name}.clab.yml
  ${copyConfigs}
''
