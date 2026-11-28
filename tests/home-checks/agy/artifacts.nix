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
    fixtureKey
    explicitExecutable
    managedCfg
    officialState
    managedAuthCfg
    apiState
    apiAuthCfg
    missingKeyState
    missingKeyCfg
    optedOutCfg
    fallbackCfg
    explicitExecutableCfg
    ;

  acpConfig = cfg: cfg.home.file.".acpx/config.json".source;
  fallbackPackage = builtins.head (agyPackages fallbackCfg);
in
pkgs.runCommand "check-home-agy-artifacts"
  {
    nativeBuildInputs = [ nushell ];
    buildInputs = [
      officialState
      apiState
      missingKeyState
    ];

    ARTIFACTS = builtins.toJSON {
      inherit explicitExecutable fixtureKey;
      profileAgy = "${managedCfg.home.profileDirectory}/bin/agy";
      instructionsPath = "${managedCfg.agents.dataDir}/instructions";
      managedAcp = acpConfig managedCfg;
      fallbackAcp = acpConfig fallbackCfg;
      explicitAcp = acpConfig explicitExecutableCfg;
      optOutAcp = acpConfig optedOutCfg;
      managedWrapper = "${managedAuthCfg.programs.antigravity-cli.package}/bin/agy";
      fallbackWrapper = "${fallbackPackage}/bin/agy";
      apiWrapper = "${apiAuthCfg.programs.antigravity-cli.package}/bin/agy";
      missingKeyWrapper = "${missingKeyCfg.programs.antigravity-cli.package}/bin/agy";
    };
  }
  ''
    nu --no-config-file ${./check-artifacts.nu}
    touch "$out"
  ''
