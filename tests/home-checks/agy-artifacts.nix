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

  eval = modules: harness.evalModules ([ homeModules.acp ] ++ modules);

  combined = eval [
    homeModules.agy
    {
      agents = {
        acp.enable = true;
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
      agents.acp = {
        enable = true;
        agyAdapter.enable = false;
      };
    }
  ];

  standalone = eval [
    {
      agents.acp = {
        enable = true;
        agyAdapter = {
          enable = true;
          package = probe;
        };
      };
      programs.antigravity-cli = {
        enable = true;
        package = pkgs.writeShellScriptBin "gemini-cli" "exit 0";
      };
    }
  ];

  acpConfig = cfg: cfg.home.file.".acpx/config.json".source;
  standaloneCli = lib.findFirst (pkg: lib.getName pkg == "agy") null standalone.home.packages;
  combinedCli = combined.programs.antigravity-cli.package;
  rolesDir = "${combined.agents.resolved.configDirs.agy}/agents";
in
assert lib.elem optOut.programs.antigravity-cli.package optOut.home.packages;
assert standaloneCli != null;
assert lib.hasInfix "model: inherit\n" combined.home.file."${rolesDir}/researcher.md".text;
assert lib.hasInfix "model: pro\n" combined.home.file."${rolesDir}/implementer.md".text;
pkgs.runCommand "home-agy-artifacts" { nativeBuildInputs = [ pkgs.jq ]; } ''
  for config in ${acpConfig combined} ${acpConfig standalone}; do
    jq -e --arg bin ${lib.escapeShellArg "${combined.home.profileDirectory}/bin/agy"} \
      '.agents.agy.argv == [$bin, "acp"]' "$config"
  done
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
