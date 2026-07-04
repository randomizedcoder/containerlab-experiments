# Single source of truth for the list of example topologies.
#
# For each example directory it imports constants.nix, feeds those constants
# into topology.nix and configs.nix, and renders a lab derivation. Both
# apps.nix and checks.nix consume this list, so a new example only has to be
# added here (plus its directory).
pkgs:
let
  renderLab = import ./render.nix pkgs;

  mk =
    dir:
    let
      constants = import (dir + "/constants.nix");
      topology = import (dir + "/topology.nix") constants;
      configs = import (dir + "/configs.nix") constants;
    in
    {
      name = constants.labName;
      lab = renderLab {
        name = constants.labName;
        inherit topology configs;
      };
    };
in
[
  (mk ../topologies/arista-mpls)
  (mk ../topologies/nokia-mpls)
]
