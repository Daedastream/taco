#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Testing and Monitoring Functions

# Create test coordinator script
create_test_coordinator() {
    local test_script="$ORCHESTRATOR_DIR/test_coordinator.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test Coordinator - Manages test execution and result distribution

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
TEST_LOG="$ORCHESTRATOR_DIR/test_results.log"

# Run tests and capture results
run_tests() {
    local test_type="$1"
    local agent="$2"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    echo "[$timestamp] Running $test_type tests for $agent" >> "$TEST_LOG"
    
    # Capture test output based on type
    case $test_type in
        unit)
            npm test 2>&1 | tee -a "$TEST_LOG"
            ;;
        integration)
            npm run test:integration 2>&1 | tee -a "$TEST_LOG"
            ;;
        e2e)
            npm run test:e2e 2>&1 | tee -a "$TEST_LOG"
            ;;
        api)
            # Test all registered endpoints
            jq -r '.endpoints | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read name url; do
                echo "Testing endpoint: $name at $url"
                curl -s -o /dev/null -w "%{http_code}" "$url" | tee -a "$TEST_LOG"
            done
            ;;
    esac
}

# Parse test failures and notify responsible agents
notify_test_failures() {
    local failures=$(grep -E "FAIL|ERROR|Failed" "$TEST_LOG" | tail -20)
    if [ -n "$failures" ]; then
        # Determine which agent should fix based on failure type
        if echo "$failures" | grep -q "frontend\|component\|ui"; then
            tmux send-keys -t taco:2.0 "TEST FAILURES DETECTED: $failures"
            sleep 0.2
            tmux send-keys -t taco:2.0 Enter
        fi
        if echo "$failures" | grep -q "backend\|api\|endpoint"; then
            tmux send-keys -t taco:2.1 "TEST FAILURES DETECTED: $failures"
            sleep 0.2
            tmux send-keys -t taco:2.1 Enter
        fi
        if echo "$failures" | grep -q "database\|schema\|migration"; then
            tmux send-keys -t taco:2.2 "TEST FAILURES DETECTED: $failures"
            sleep 0.2
            tmux send-keys -t taco:2.2 Enter
        fi
    fi
}

# Monitor build processes
monitor_builds() {
    while true; do
        # Check for build errors in common locations
        for build_log in */build.log */logs/build.log .next/build-error.log; do
            if [ -f "$build_log" ] && grep -q "ERROR\|FAIL" "$build_log"; then
                echo "Build error detected in $build_log"
                notify_test_failures
            fi
        done
        sleep 5
    done
}

# Start monitoring based on arguments
case "$1" in
    test) run_tests "$2" "$3" ;;
    monitor) monitor_builds ;;
    notify) notify_test_failures ;;
    *) echo "Usage: $0 {test|monitor|notify}" ;;
esac
EOF
    chmod +x "$test_script"
    log "INFO" "TEST-COORD" "Created test coordinator script"
}