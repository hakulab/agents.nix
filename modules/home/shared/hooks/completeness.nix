# ==================================================================================================
# Completeness Hook
# ==================================================================================================

{
  scriptsDir,
  timeouts,
}:

{
  event = "Stop";
  type = "prompt";
  timeout = timeouts.modelCall;
  statusMessage = "Checking completeness";
  prompt = builtins.readFile (scriptsDir + "/claude-code/hooks/completeness/prompt.md");
}
