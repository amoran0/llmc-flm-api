Feature: Run benchmark script

  Scenario: Run benchmark with explicit model lists
    Given a list of FLM models "model1 model2"
    And a list of llama.cpp models "llama1 llama2"
    When I run the benchmark script
    Then the FLM benchmark log should contain 2 correctly formatted entries
    And the llama.cpp benchmark log should contain 2 correctly formatted entries

  Scenario: Run benchmark with empty FLM model list
    Given a list of FLM models ""
    And a list of llama.cpp models "llama1"
    When I run the benchmark script
    Then the FLM benchmark log should contain 0 correctly formatted entries
    And the llama.cpp benchmark log should contain 1 correctly formatted entry

  Scenario: Logged entries include the configured prompt
    Given a list of FLM models "model1"
    And a list of llama.cpp models "llama1"
    And a prompt "write a terraform snippet that deploys an ec2 instance"
    When I run the benchmark script
    Then every benchmark log entry should include the prompt "write a terraform snippet that deploys an ec2 instance"
