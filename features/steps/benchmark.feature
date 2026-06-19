Feature: Benchmark script

  Scenario: Run benchmark with explicit llama.cpp model lists
    Given a list of llama.cpp models "glm-4.7-flash gpt-oss-20b-q4-k-m"
    When I run the benchmark script
    Then the llama.cpp benchmark log should contain 2 correctly formatted entries

  Scenario: Run benchmark with empty llama.cpp model list
    Given a list of llama.cpp models ""
    When I run the benchmark script
    Then the llama.cpp benchmark log should contain 0 correctly formatted entries

  Scenario: Logged entries include the configured prompt
    Given a list of llama.cpp models "gpt-oss-20b-q4-k-m"
    And a prompt "write a terraform snippet that deploys an ec2 instance"
    When I run the benchmark script
    Then every benchmark log entry should include the prompt "write a terraform snippet that deploys an ec2 instance"

  Scenario: Llama.cpp benchmark log entries contain all required fields and are not empty
    Given a list of llama.cpp models "glm-4.7-flash"
    When I run the benchmark script
    Then each llama.cpp benchmark log entry should contain all required fields and non-empty values
