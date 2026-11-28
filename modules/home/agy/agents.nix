# ==================================================================================================
# Antigravity CLI Custom Agents
# ==================================================================================================

{
  lib,
  resolved,
  enabledAgents,
}:

let
  inherit (import ./models.nix { inherit lib resolved; }) tierFor;

  renderFrontmatter =
    name: agent:
    let
      settings = removeAttrs agent.agy [
        "name"
        "description"
        "mainAgent"
        "model"
      ];

      frontmatterLines = [
        "name: ${builtins.toJSON name}"
        "description: ${builtins.toJSON agent.description}"
        "mainAgent: ${lib.boolToString (agent.agy.mainAgent or false)}"
        "model: ${tierFor agent.workload}"
      ]
      ++ lib.mapAttrsToList (field: value: "${field}: ${builtins.toJSON value}") settings;
    in
    lib.concatStringsSep "\n" ([ "---" ] ++ frontmatterLines ++ [ "---" ]);

  renderAgent = name: agent: ''
    ${renderFrontmatter name agent}

    ${agent.prompt}
  '';
in
{
  homeFiles = lib.mapAttrs' (
    name: agent:
    lib.nameValuePair "${resolved.configDirs.agy}/agents/${name}.md" {
      text = renderAgent name agent;
    }
  ) (lib.filterAttrs (name: _: lib.elem name enabledAgents) resolved.agentRoles);
}
