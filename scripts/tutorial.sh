#!/usr/bin/env bash
python -m testsavant_redteaming.cli --api-key "$TESTSAVANT_API_KEY" run-and-wait --redteaming-id "$REDTEAM_ID" --strict "$@" > result.json
