# ==================================================================================================
# Built-In MCP Server Presets
# ==================================================================================================

{
  self,
  agentsLib,
}:

{
  imports = [
    (import ./atlassian.nix { inherit agentsLib; })
    (import ./chrome-devtools.nix { inherit agentsLib; })
    (import ./deepwiki.nix { inherit agentsLib; })
    (import ./exa.nix { inherit agentsLib; })
    (import ./github.nix { inherit self agentsLib; })
    (import ./gitlab.nix { inherit self agentsLib; })
    (import ./scrapling.nix { inherit agentsLib; })
  ];
}
