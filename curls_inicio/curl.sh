#!/bin/bash

curl -s -X POST "http://192.168.0.142:52625/v1/completions" \
     -H "Content-Type: application/json" \
     -d '{"model":"llama3.1:8b","prompt":"Hello world"}'
