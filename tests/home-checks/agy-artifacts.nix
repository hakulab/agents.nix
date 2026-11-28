# ==================================================================================================
# Antigravity CLI Home Manager Artifact Checks
# ==================================================================================================

{
  pkgs,
  lib,
  harness,
  homeModules,
}:

let
  probe = pkgs.writeShellScriptBin "agy" ''
    printf '%s\n' "$HTTPS_PROXY" "$NO_PROXY" "$@"
  '';

  eval =
    modules:
    harness.evalModules (
      [
        homeModules.acp
        { agents.acp.enable = true; }
      ]
      ++ modules
    );

  combined = eval [
    homeModules.agy
    {
      agents = {
        agy = {
          enable = true;
          package = probe;
        };
        models = {
          defaults.gemini.default = "gemini-4-hydrogen";
          workloadPolicy.gemini.default = "medium";
          catalog.gemini-4-hydrogen.channelId.google = "gemini/gemini-4-hydrogen";
        };
        proxy = {
          enable = true;
          url = "https://proxy.example.test";
          noProxy = [ "direct.example.test" ];
        };
      };
    }
  ];

  optOut = eval [
    homeModules.agy
    {
      agents.agy = {
        enable = true;
        package = probe;
      };
      agents.acp.agyAdapter.enable = false;
    }
  ];

  standalone = eval [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = probe;
      };
      programs.antigravity-cli = {
        enable = true;
        package = pkgs.writeShellScriptBin "gemini-cli" "exit 0";
      };
    }
  ];

  explicitExecutable = "/fixtures/local/bin/agy";
  explicit = eval [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = probe;
        executable = explicitExecutable;
      };
    }
  ];

  managedWithNullExecutable = eval [
    {
      agents.acp.agyAdapter = {
        enable = true;
        package = probe;
        executable = null;
      };
      programs.antigravity-cli = {
        enable = true;
        package = probe;
      };
    }
  ];

  acpConfig = cfg: cfg.home.file.".acpx/config.json".source;
  agyPackages = cfg: lib.filter (pkg: lib.getName pkg == "agy") cfg.home.packages;
  standalonePackages = agyPackages standalone;
  standaloneCli = builtins.head standalonePackages;
  combinedCli = combined.programs.antigravity-cli.package;
  profileAgy = "${combined.home.profileDirectory}/bin/agy";
  rolesDir = "${combined.agents.resolved.configDirs.agy}/agents";
in
assert lib.elem optOut.programs.antigravity-cli.package optOut.home.packages;
assert combined.agents.acp.agyAdapter.executable == profileAgy;
assert standalone.agents.acp.agyAdapter.executable == null;
assert builtins.length standalonePackages == 1;
assert agyPackages explicit == [ ];
assert agyPackages managedWithNullExecutable == [ probe ];
assert lib.hasInfix "model: inherit\n" combined.home.file."${rolesDir}/researcher.md".text;
assert lib.hasInfix "model: pro\n" combined.home.file."${rolesDir}/implementer.md".text;
pkgs.runCommand "home-agy-artifacts" { nativeBuildInputs = [ pkgs.jq ]; } ''
  for config in \
    ${acpConfig combined} \
    ${acpConfig standalone} \
    ${acpConfig managedWithNullExecutable}; do
    jq -e --arg bin ${lib.escapeShellArg profileAgy} \
      '.agents.agy.argv == [$bin, "acp"]' "$config"
  done
  jq -e --arg bin ${lib.escapeShellArg explicitExecutable} \
    '.agents.agy.argv == [$bin, "acp"]' ${acpConfig explicit}
  jq -e '.agents | has("agy") | not' ${acpConfig optOut}

  ${combinedCli}/bin/agy --model gemini-pro-orchestrator-neon > args
  diff -u - args <<'EXPECTED'
  https://proxy.example.test
  localhost,127.0.0.1,10.0.0.0/8,direct.example.test
  --model
  gemini-4-hydrogen-medium
  --model
  gemini-pro-orchestrator-neon
  EXPECTED

  env -u HTTPS_PROXY -u NO_PROXY ${standaloneCli}/bin/agy acp > args
  diff -u - args <<'EXPECTED'


  --model
  gemini-4-neon-low
  acp
  EXPECTED
  touch "$out"
''
