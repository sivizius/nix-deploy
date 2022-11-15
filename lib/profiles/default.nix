{ core, ... }:
let
  inherit (core) list;

  Profile
  =
in
{
  inherit Profile;

  import
  =   { nixpkgs, system, ... }:
        list.fold
        (
          result:
          profile:
            result
            //  {
                  ${profile}
                  =   Profile
                      {
                        __type__        =   "Profile";
                        config
                        =   { lib, ... }:
                              import "${nixpkgs}/nixos/modules/profiles/${profile}.nix"
                              {
                                config  =   null;
                                lib     =   lib.nixlib;
                                modules =   null;
                                pkgs    =   null;
                              };
                        parents         =   [ ];
                        services        =   [ ];
                      };
                }
        )
        {};
}