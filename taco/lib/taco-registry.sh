#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Connection Registry and Port Management

# Create connection registry for tracking ports and endpoints
create_connection_registry() {
    local registry_file="$ORCHESTRATOR_DIR/connections.json"
    cat > "$registry_file" << 'EOF'
{
    "services": {},
    "endpoints": {},
    "ports": {},
    "database_urls": {},
    "api_keys": {},
    "test_results": {},
    "build_status": {}
}
EOF
    log "INFO" "REGISTRY" "Created connection registry at $registry_file"
}

# Create port allocation helper with deployment awareness
create_port_helper() {
    local helper_script="$ORCHESTRATOR_DIR/port_helper.sh"
    cat > "$helper_script" << 'EOF'
#!/bin/bash
# Port Helper - Manages port allocation and conflicts with deployment awareness

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"

# Get deployment environment
get_deployment_env() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.deployment_env // "local"' "$CONNECTIONS_FILE" 2>/dev/null
    else
        echo "local"
    fi
}

# Get next available port based on deployment environment
get_next_port() {
    local start_port=${1:-3010}
    local deployment_env=$(get_deployment_env)
    
    # Adjust port range based on deployment environment
    case $deployment_env in
        "docker")
            start_port=${start_port:-8010}  # Higher ports for Docker
            ;;
        "cloud")
            start_port=${start_port:-8010}  # Higher ports for cloud
            ;;
        *)
            start_port=${start_port:-3010}  # Standard ports for local
            ;;
    esac
    
    local reserved_ports
    if command -v jq >/dev/null 2>&1; then
        reserved_ports=$(jq -r '.port_allocation.reserved[]' "$CONNECTIONS_FILE" 2>/dev/null | tr '\n' ' ')
    else
        reserved_ports="3000 3001 3002 3003 5432 6379 8080 9090"
    fi
    
    for port in $(seq $start_port 9999); do
        if ! echo "$reserved_ports" | grep -q "$port" && ! netstat -ln 2>/dev/null | grep -q ":$port "; then
            echo $port
            return
        fi
    done
    echo $start_port
}

# Allocate port to service with deployment-specific logic
allocate_port() {
    local service="$1"
    local preferred_port="$2"
    local deployment_env=$(get_deployment_env)
    
    # Apply deployment-specific port mapping
    if [ -z "$preferred_port" ]; then
        case $deployment_env in
            "docker")
                case $service in
                    "frontend") preferred_port=80 ;;
                    "backend") preferred_port=8000 ;;
                    "api") preferred_port=8001 ;;
                    "testing") preferred_port=8002 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
            "cloud")
                case $service in
                    "frontend") preferred_port=80 ;;
                    "backend") preferred_port=8000 ;;
                    "api") preferred_port=8001 ;;
                    "testing") preferred_port=8002 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
            *)
                case $service in
                    "frontend") preferred_port=3000 ;;
                    "backend") preferred_port=3001 ;;
                    "api") preferred_port=3002 ;;
                    "testing") preferred_port=3003 ;;
                    *) preferred_port=$(get_next_port) ;;
                esac
                ;;
        esac
    fi
    
    # Check if preferred port is available
    if netstat -ln 2>/dev/null | grep -q ":$preferred_port "; then
        echo "Port $preferred_port is already in use, finding alternative" >&2
        preferred_port=$(get_next_port)
    fi
    
    # Update registry
    if command -v jq >/dev/null 2>&1; then
        jq ".ports.\"$service\" = $preferred_port | .port_allocation.reserved += [$preferred_port]" "$CONNECTIONS_FILE" > /tmp/conn_update.json
        mv /tmp/conn_update.json "$CONNECTIONS_FILE"
    else
        echo "Port $preferred_port allocated to $service" >> "$ORCHESTRATOR_DIR/port_allocation.log"
    fi
    
    echo $preferred_port
}

# Show port usage with deployment context
show_ports() {
    local deployment_env=$(get_deployment_env)
    echo "=== PORT ALLOCATION ($deployment_env) ==="
    
    if command -v jq >/dev/null 2>&1; then
        jq -r '.ports | to_entries[] | "\(.key): \(.value)"' "$CONNECTIONS_FILE"
    else
        echo "jq not available - check $CONNECTIONS_FILE manually"
    fi
    
    echo
    echo "Next available: $(get_next_port)"
    echo "Deployment environment: $deployment_env"
}

# Generate Docker-compatible URLs
generate_docker_urls() {
    local service="$1"
    local port="$2"
    local deployment_env=$(get_deployment_env)
    
    case $deployment_env in
        "docker")
            echo "http://$service:$port"
            ;;
        "cloud")
            echo "https://$service.your-domain.com"
            ;;
        *)
            echo "http://localhost:$port"
            ;;
    esac
}

case "$1" in
    next) get_next_port "$2" ;;
    allocate) allocate_port "$2" "$3" ;;
    show) show_ports ;;
    docker-url) generate_docker_urls "$2" "$3" ;;
    *) echo "Usage: $0 {next|allocate|show|docker-url} [service] [port]" ;;
esac
EOF
    chmod +x "$helper_script"
    log "INFO" "PORT-HELPER" "Created deployment-aware port allocation helper"
}

# Create connection validator
create_connection_validator() {
    local validator_script="$ORCHESTRATOR_DIR/validate_connections.sh"
    cat > "$validator_script" << 'EOF'
#!/bin/bash
# Connection Validator - Ensures all services can communicate

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
VALIDATION_LOG="$ORCHESTRATOR_DIR/validation.log"

validate_all_connections() {
    echo "=== CONNECTION VALIDATION REPORT ===" > "$VALIDATION_LOG"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$VALIDATION_LOG"
    echo >> "$VALIDATION_LOG"
    
    # Validate all registered services
    jq -r '.services | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read service url; do
        echo "Checking $service at $url..." >> "$VALIDATION_LOG"
        if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "200\|201\|204"; then
            echo "✓ $service is accessible" >> "$VALIDATION_LOG"
        else
            echo "✗ $service is NOT accessible" >> "$VALIDATION_LOG"
            # Notify Mother about connection issue
            tmux send-keys -t taco:0.0 "CONNECTION ISSUE: $service at $url is not accessible"
            sleep 0.2
            tmux send-keys -t taco:0.0 Enter
        fi
    done
    
    # Check for port conflicts
    echo >> "$VALIDATION_LOG"
    echo "Port Usage:" >> "$VALIDATION_LOG"
    jq -r '.ports | to_entries[] | "\(.key): \(.value)"' "$CONNECTIONS_FILE" >> "$VALIDATION_LOG"
    
    # Check for localhost vs docker networking issues
    if jq -r '.services | to_entries[].value' "$CONNECTIONS_FILE" | grep -q "localhost"; then
        if docker ps -q 2>/dev/null | wc -l | grep -q "[1-9]"; then
            echo "⚠️  WARNING: Using 'localhost' with Docker containers running!" >> "$VALIDATION_LOG"
            echo "Consider using 'host.docker.internal' or container names instead." >> "$VALIDATION_LOG"
        fi
    fi
}

# Run validation
validate_all_connections

# Show results
cat "$VALIDATION_LOG"
EOF
    chmod +x "$validator_script"
    log "INFO" "VALIDATOR" "Created connection validator script"
}