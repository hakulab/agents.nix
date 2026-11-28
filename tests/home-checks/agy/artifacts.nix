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
    officialAuthCfg
    fixtureKey
    apiAuthCfg
    apiState
    missingKeyCfg
    ;

  acpConfig = cfg: cfg.home.file.".acpx/config.json".source;
  combinedPackage = combinedCfg.programs.antigravity-cli.package;
  fallbackPackage = builtins.head (agyPackages fallbackCfg);
in
pkgs.runCommand "home-agy-artifacts"
  {
    nativeBuildInputs = [ nushell ];
    buildInputs = [ apiState ];

    ARTIFACTS = builtins.toJSON {
      inherit explicitExecutable fixtureKey;
      profileAgy = "${combinedCfg.home.profileDirectory}/bin/agy";
      instructionsPath = "${officialAuthCfg.agents.dataDir}/instructions";
      profileConfigs = map acpConfig [
        combinedCfg
        fallbackCfg
        nullExecutableCfg
      ];
      explicit = acpConfig explicitExecutableCfg;
      optOut = acpConfig optedOutCfg;
      combinedWrapper = "${combinedPackage}/bin/agy";
      fallbackWrapper = "${fallbackPackage}/bin/agy";
      officialAuth = "${officialAuthCfg.programs.antigravity-cli.package}/bin/agy";
      apiAuth = "${apiAuthCfg.programs.antigravity-cli.package}/bin/agy";
      missingKey = "${missingKeyCfg.programs.antigravity-cli.package}/bin/agy";
    };
  }
  ''
    nu --no-config-file ${./check-artifacts.nu}
    touch "$out"
  ''
