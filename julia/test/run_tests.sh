#!/bin/bash

# Change to the test directory
cd "$(dirname "$0")"

# Run the tests
julia --project=.. runtests.jl
