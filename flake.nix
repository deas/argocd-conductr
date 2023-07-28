{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.11";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  # https://devenv.sh/reference/options/
                  packages = [
                     pkgs.argocd-autopilot
                     pkgs.argocd
		                 pkgs.kustomize-sops
                     # pkgs.terraform
                     # pkgs.kubernetes-helm
                     # pkgs.kustomize
                     # pkgs.kubernix
                     # pkgs.gnumake
                     # pkgs.github-cli
                     # pkgs.babashka
                     # pkgs.grafana-loki
                     # pkgs.kubectl
                     # pkgs.istioctl
                     # pkgs.just
                  ];

                  enterShell = ''
                    export LOKI_ADDR="http://localhost:3100"
                  '';
                }
              ];
            };
          });
    };
}
