{ core, ... }:
let
  inherit (core.type) struct;
in
{
  Service
  =   struct "deploy::services::Service"
      {

      };
}