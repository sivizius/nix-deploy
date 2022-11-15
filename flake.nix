{
  description                           =   "Deploy NixOS-Configurations";
  inputs
  =   {
        libcore.url                     =   "github:sivizius/nix-libcore/development";
        nixpkgs.url                     =   "github:NixOS/nixpkgs/master";
      };
  outputs
  =   { libcore, nixpkgs, ... }:
        let
          core                          =   libcore.lib;
          stdenv
          =   target.System.mapStdenv
              (
                system:
                  nixpkgs.legacyPackages.${string system}.stdenv
              );
          inherit(core) string target;
        in
        {
          inherit stdenv;
          lib
          =   import ./lib
              {
                inherit core stdenv;
                context                 =   [ "deploy" ];
              };
        };
}