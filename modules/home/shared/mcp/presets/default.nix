# ==================================================================================================
# Built-In MCP Server Presets
# ==================================================================================================

{
  agentsLib,
  packagesFor,
}:

{
  imports = [
    (import ./atlassian.nix { inherit agentsLib; })
    (import ./chrome-devtools.nix { inherit agentsLib; })
    (import ./deepwiki.nix { inherit agentsLib; })
    (import ./exa.nix { inherit agentsLib; })
    (import ./github.nix { inherit agentsLib packagesFor; })
    (import ./gitlab.nix { inherit agentsLib packagesFor; })
    (import ./scrapling.nix { inherit agentsLib; })
  ];
}
