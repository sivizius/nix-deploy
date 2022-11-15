{ context, core, ... } @ libs:
let
  inherit(core) list path;
  load
  =   list.mapToList
      (
        directory:
          let
            name                        =   path.baseName directory;
          in
          {
            inherit name;
            value
            =   import directory
                (
                  libs
                  //  {
                        context         =   context ++ [ name ];
                      }
                );
          }
      );
in
  load
  [
    ./hosts
    ./modules
    ./profiles
    ./registries
    ./services
    ./users
  ]
