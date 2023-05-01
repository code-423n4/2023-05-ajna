#!/bin/bash

forge coverage --report lcov

lcov -r lcov.info "script/*" "test/*" -o lcov-filtered.info --rc lcov_branch_coverage=1

genhtml lcov-filtered.info -o report --branch-coverage && firefox report/index.html
