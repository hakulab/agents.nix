# ==================================================================================================
# Antigravity CLI Home Manager Artifact Checks
# ==================================================================================================

{
  pkgs,
  nushell,
  fixtures,
}:

let
  inherit (fixtures)
    agyPackages
    combinedCfg
    optedOutCfg
    fallbackCfg
    explicitExecutable
    explicitExecutableCfg
    nullExecutableCfg
    ;

  acpConfig = cfg: cfg.home.file.".acpx/config.json".source;
  combinedPackage = combinedCfg.programs.antigravity-cli.package;
  fallbackPackage = builtins.head (agyPackages fallbackCfg);
in
pkgs.runCommand "home-agy-artifacts"
  {
    nativeBuildInputs = [ nushell ];

    ARTIFACTS = builtins.toJSON {
      inherit explicitExecutable;
      profileAgy = "${combinedCfg.home.profileDirectory}/bin/agy";
      profileConfigs = map acpConfig [
        combinedCfg
        fallbackCfg
        nullExecutableCfg
      ];
      explicit = acpConfig explicitExecutableCfg;
      optOut = acpConfig optedOutCfg;
      combinedWrapper = "${combinedPackage}/bin/agy";
      fallbackWrapper = "${fallbackPackage}/bin/agy";
    };
  }
  ''
    nu --no-config-file ${./check-artifacts.nu}
    touch "$out"
  ''
