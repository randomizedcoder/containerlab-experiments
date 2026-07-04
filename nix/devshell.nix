# `nix develop` shell for driving the labs by hand.
_: {
  perSystem =
    { pkgs, config, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.containerlab
          pkgs.docker-client
          pkgs.yq-go
          pkgs.yamllint
          config.treefmt.build.wrapper
        ];
        shellHook = ''
          echo "containerlab-experiments dev shell"
          echo "  nix run .#arista-mpls-up   # deploy the Arista example"
          echo "  nix run .#nokia-mpls-up    # deploy the Nokia example"
          echo "  nix fmt / nix flake check"
        '';
      };
    };
}
