{ ... }:
{
  Local
  =   {
        method                          =   "local";
      };
  SSH
  =   { user ? null, host, key ? null, port ? 22 }:
      {
        method                          =   "ssh";
        data                            =   { inherit user host key port; };
      };
}