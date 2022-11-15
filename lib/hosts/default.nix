{ core, stdenv, ... }:
let
  inherit(core)   list path set string system time;
  inherit(stdenv) mkDerivation;

  loadParents
  =   { config, lib, host, pkgs, profile, ... } @ arguments:
      (
        let
          loadParents'      =   loadParents arguments;
        in
          list.map
          (
            parent:
            (
              type.matchOrFail parent
              {
                "lambda"
                =   loadParents'
                    (
                      parent
                      {
                        inherit host lib libs pkgs profile;
                        inherit (libs) core intrinsics;
                        config
                        =   trace
                              "Please remove dependency on `config` in profile ${parent.name}"
                              config;
                      }
                    );
                "list"      =   loadParents' parent;
                "path"      =   loadParents' (import parent);
                "set"       =   parent;
              }
            )
          )
      );

  loadServices
  =   { config, lib, host, pkgs, profile, ... }:
      (
        list.map
        (
          service:
          (
            service.config
            {
              inherit host lib libs pkgs;
              inherit (config) services;
              inherit (libs) core intrinsics;
              config
              =   trace
                    "Please remove dependency on `config` in service ${service.name}"
                    config;
            }
          )
        )
      );

  loadUsers
  =   { config, lib, host, pkgs, profile, ... }:
      (
        list.map
        (
          user:
          (
            user.config
            {
              inherit config lib libs pkgs profile user;
              inherit (libs) core intrinsics;
            }
          )
        )
      );

  checkNetwork#: Network -> Network | !
  =   network:
        network;

  checkProfile#: Profile -> Profile | !
  =   profile:
        if set.isSet profile
        then
          profile
        else
          core.panic "Invalid Profile!";

  prepareHostConfig#:
  # HostName = string,
  # HostConfig = { about, profile, deployment, network, users, ... },
  # @   { dateTime: DateTime, hostsDirectory: path, ... }
  # ->  HostName
  # ->  HostConfig
  # ->  HostConfig
  =   { dateTime, hostsDirectory, ... }:
      name:
      hostConfig:
        let
          # Check/Adjust given configuration
          about                         =   string.replace [ "\n" ] [ "\n#   " ] hostConfig.about;

          deployment
          =   {
                "local"
                =   {
                      method            =   "local";
                      address           =   "file:///";
                    };
                "ssh"
                =   let
                      data              =   deployment.data;
                      user              =   data.user or  null;
                      host              =   data.host or  name;
                      port              =   data.port or  22;
                      key               =   data.key  or  null;

                      user'             =   if user != null then "${user}@"   else "";
                      key'              =   if key  != null then " -i ${key}" else "";
                    in
                    {
                      method            =   "ssh";
                      inherit user host port key;
                      address           =   "ssh://${user'}${host}";
                    };
              }.${hostConfig.deployment.method} or (core.panic "Invalid Deployment Method ${hostConfig.deployment.method}");

          network                       =   checkNetwork hostConfig.network;

          path
          =   if hostConfig.path != null
              then
                hostConfig.path
              else
                hostsDirectory + "/${name}";

          profile                       =   checkProfile hostConfig.profile;

          users
          =   map
              (
                name:
                  let
                    user                =   config.users.${name};
                    config              =   user.config or {};
                  in
                  {
                    inherit name config;
                  }
              )
              hostsDirectory.users;

          # Build/Deploy-Scripts
          buildScript
          =   path.toFile "deploy-${name}.sh"
              ''
                ${scriptHeader}
                # Build ${name}
              '';

          deployScript
          =   path.toFile "deploy-${name}.sh"
              ''
                ${scriptHeader}
                # Deploy ${name} via ${deployment.method}
                #nix copy --to ${deployment.address} ???
              '';

          scriptHeader
          =   ''
                #!/usr/bin/env sh
                # Name: ${name}
                # Description: ${about}
                # Date and Time: ${dateTime.year}-${dateTime.month}-${dateTime.day} ${dateTime.hour}:${dateTime.minute}:${dateTime.second}
                # Host-Config: ${path}
              '';
        in
        {
          __type__                      =   "Host";
          inherit about deployment name network path profile users;
          inherit buildScript deployScript;
          builder
          =   path.toFile "${name}.sh"
              ''
                source $stdenv/setup
                mkdir -p $out
                ln -s ${buildScript} $out/build.sh
                ln -s ${deployScript} $out/deploy.sh
              '';
        };

  mapHost
  =   name:
      hostConfig:
        let

          arguments
          =   {
                host                =   hostConfig;
                inherit profile;
              };
          config
          =   { config, lib, pkgs, ... }:
              let
                arguments           =   { inherit config host lib pkgs profile; };
              in
              (
                loadParents   arguments host.profile.parents
              );

          modules'
          =   ( attrValues    modules.nixosModules            )
          ++  [ ( args: __trace ( __attrNames args ) {} ) ]
          ++  ( [] )
          ++  ( loadServices  arguments host.profile.services )
          ++  ( loadUsers     arguments host.users            )
          ++  [ ( host.config or ( import (./. + "/${name}" )) ) ];
        in
          hostConfig
          //  {

                inherit name ;


                modules             =   modules';
                config              =   null;
              };

  from#:
  # { dateTime: DateTime, hostsDirectory: path, ... }
  # -> { hostname -> Host }
  # -> { hostname -> Host }
  # where hostname = string
  =   { dateTime, hostsDirectory, ... } @ arguments:
      ( set.map ( prepareHost arguments ) );
in
{
  __functor                             =   self: from;

  inherit from;

  mapToConfigurations#: { hostname -> Host } -> { hostname -> ? } where hostname = string
  =   set.map
      (
        name:
        hostConfig:
          nixlib.nixosSystem
          {
            system                      =   hostConfig.system or system.current;
            modules                     =   [ hostConfig.config ];
          }
      );

  mapToDefaultDerivation#: { hostname -> Host } -> derivation where hostname = string
  =   hosts:
      {
        default
        =   let
              hostNames                 =   set.names hosts;
              mkdir                     =   list.map (hostDir: "mkdir -p $out/${hostDir}") hostNames;

              buildScripts
              =   set.mapToList
                    (name: config: "ln -s ${config.buildScript}  $out/${name}/build.sh" )
                    hosts;
              buildAllScript
              =   path.toFile "build.sh"
                  ''
                    #!/usr/bin/env sh
                    ${string.concatLines (list.map (hostDir: "./${hostDir}/build.sh") hostNames)}
                  '';

              deployScripts
              =   set.mapToList
                    (name: config: "ln -s ${config.deployScript} $out/${name}/deploy.sh")
                    hosts;
              deployAllScript
              =   path.toFile "deploy.sh"
                  ''
                    #!/usr/bin/env sh
                    ${string.concatLines (list.map (hostDir: "./${hostDir}/deploy.sh") hostNames)}
                  '';
            in
              mkDerivation
              {
                name                    =   "all";
                buildInputs             =   [ ];
                builder
                =   path.toFile "builder.sh"
                    ''
                      source $stdenv/setup
                      mkdir -p $out
                      ${string.concatLines mkdir}
                      ${string.concatLines buildScripts}
                      ${string.concatLines deployScripts}
                      ln -s ${buildAllScript} $out/build.sh
                      ln -s ${deployAllScript} $out/deploy.sh
                    '';
              };
      };

  mapToDerivations#: { hostname -> Host } -> { hostname -> derivation } where hostname = string
  =   set.map
      (
        name:
        hostConfig:
          mkDerivation
          {
            inherit (hostConfig) builder;
            inherit name;
            buildInputs                 =   [ ];
          }
      );

  Host#: { about, deployment, profile, users, ... } -> Host
  =   { about, deployment, profile, users, ... } @ config:
      config // { __type__ = "Host"; __variant__ = "Host"; };

  Peer#: { about, ... } -> Host
  =   { about, ... } @ config:
      config // { __type__ = "Host"; __variant__ = "Peer"; };

  Network
  =   about:
      { ... } @ hosts:
      {
        __type__                        =   "Network";
        inherit about hosts
      };
}