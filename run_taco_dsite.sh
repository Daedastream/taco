#!/bin/bash
cd /Users/louisxsheid/Dev/daedastream/d-site
export ORCHESTRATOR_TIMEOUT=300
exec /Users/louisxsheid/Dev/Daedastream/taco/taco/bin/taco "$@"