#!/usr/bin/env nu

# ==================================================================================================
# Model Call Tests
# ==================================================================================================

use std/assert
use test-runner.testlib.nu [run-script]

const SCRIPT_DIR = path self "."
const SCRIPT = ($SCRIPT_DIR | path join "model-call.nu")

const TOKEN = "stub-gateway-token"
const CURL_ARGS = [
  -fsSL
  --connect-timeout "5"
  --max-time "90"
]

# --------------------------------------------------------------------------------------------------
# Test helpers
# --------------------------------------------------------------------------------------------------

# `run` is the completed model call, `calls` holds what each curl call received, and `token_file`
# is the token's path.
def call [
  request: record
  reply: record
  --gateway: record = {}
]: nothing -> record {
  let dir = (mktemp --directory)
  let config_file = ($dir | path join "config.json")
  let token_file = ($dir | path join "token")
  let log = ($dir | path join "calls.jsonl")

  $"($TOKEN)\n" | save $token_file
  let default_gateway = {
    baseUrl: "https://gateway.test"
    tokenFile: $token_file
    caFile: "/ca.pem"
  }
  {
    gateway: ($default_gateway | merge $gateway)
    curl: ($env.NU_TEST_STUBS | path join "curl")
    curlArgs: $CURL_ARGS
  }
  | to json
  | save $config_file

  let run = with-env {
    STUB_LOG: $log
    STUB_REPLY: ($reply | to json)
  } {
    $request
    | to json
    | run-script $SCRIPT --config $config_file
  }
  {
    run: $run
    calls: (open $log | from json --objects)
    token_file: $token_file
  }
}

def reply [content: string, finish: string]: nothing -> record {
  {
    choices: [
      {
        finish_reason: $finish
        message: {content: $content}
      }
    ]
  }
}

# --------------------------------------------------------------------------------------------------
# Request dispatch and reply handling
# --------------------------------------------------------------------------------------------------

def "test a request passes the token by file and prints the reply" [] {
  let request = {
    model: "stub"
    maxTokens: 64
    system: "Judge."
    user: "Text."
    json: true
  }

  let result = (call $request (reply "ok: true" "stop"))
  assert equal $result.run.exit_code 0 $result.run.stderr

  assert equal $result.run.stdout "ok: true"
  assert equal $result.calls [
    {
      args: [
        "https://gateway.test/v1/chat/completions"
        ...$CURL_ARGS
        --cacert "/ca.pem"
        --variable $"token@($result.token_file)"
        --expand-header "Authorization: Bearer {{token:trim}}"
        --header "content-type: application/json"
        --data @-
      ]
      body: {
        model: "stub"
        max_tokens: 64
        stream: false
        tool_choice: "none"
        messages: [
          [role content];
          ["system" "Judge."]
          ["user" "Text."]
        ]
        response_format: {type: "json_object"}
      }
    }
  ]
}

def "test gateway base URLs resolve to one version segment" [] {
  let request = {
    model: "stub"
    maxTokens: 64
    system: "Judge."
    user: "Text."
  }
  let cases = [
    [base_url endpoint];
    ["https://gateway.test/v1" "https://gateway.test/v1/chat/completions"]
    ["https://gateway.test/team/v1/" "https://gateway.test/team/v1/chat/completions"]
    ["https://gateway.test/team/" "https://gateway.test/team/v1/chat/completions"]
    ["https://v1" "https://v1/v1/chat/completions"]
  ]

  for case in $cases {
    let result = (call $request (reply "ok" "stop") --gateway {baseUrl: $case.base_url})
    assert equal $result.run.exit_code 0 $result.run.stderr
    assert equal $result.calls.0.args.0 $case.endpoint $case.base_url
  }
}

def "test a reply cut short fails with its finish reason" [] {
  let request = {
    model: "stub"
    maxTokens: 64
    system: "Judge."
    user: "Text."
  }

  let result = (call $request (reply "ok:" "length"))

  assert equal $result.run.exit_code 1
  assert equal $result.run.stdout ""
  assert equal $result.run.stderr "model-call: the gateway reply ended with finish_reason length\n"
}

def "test optional caFile and tokenFile can be omitted and extraHeaders are sorted" [] {
  let request = {
    model: "stub"
    maxTokens: 64
    system: "Judge."
    user: "Text."
  }

  let result = (
    call $request (reply "ok" "stop") --gateway {
      caFile: null
      tokenFile: null
      extraHeaders: {
        "x-zeta": "2"
        "x-alpha": "1"
      }
    }
  )

  assert equal $result.run.exit_code 0 $result.run.stderr
  assert equal $result.run.stdout "ok"
  assert equal $result.calls.0.args [
    "https://gateway.test/v1/chat/completions"
    ...$CURL_ARGS
    --header "x-alpha: 1"
    --header "x-zeta: 2"
    --header "content-type: application/json"
    --data @-
  ]
}
