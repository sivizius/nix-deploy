{ core, ... }:
let
  inherit(core) set;
in
{
  foo
  =   { profile, ... } @ env:
      set.map
      (
        name:
        { config, ... } @ user:
          user
          //  {
                inherit name;
                config                  =   config ( env // { inherit user; } );
              }
      );
}