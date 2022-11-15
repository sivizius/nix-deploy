{ ... }:
let
  mount
  =   fsType:
      label:
      device:
      config:
        config // { inherit device fsType label; };
in
{
  __functor                             =   _: mount;
  vfat                                  =   mount "vfat";
  xfs                                   =   mount "xfs";
}
