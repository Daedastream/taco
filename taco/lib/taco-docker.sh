#!/usr/bin/env bash
# TACO - Tmux Agent Command Orchestrator
# Docker Integration

# Create Docker compose generator for containerized deployments
create_docker_generator() {
    local docker_script="$ORCHESTRATOR_DIR/docker_generator.sh"
    cat > "$docker_script" << 'EOF'
#!/bin/bash
# Docker Generator - Creates docker-compose.yml based on services

ORCHESTRATOR_DIR="$(dirname "$0")"
CONNECTIONS_FILE="$ORCHESTRATOR_DIR/connections.json"
DOCKER_COMPOSE_FILE="docker-compose.yml"

# Generate docker-compose.yml from connection registry
generate_docker_compose() {
    local deployment_env
    if command -v jq >/dev/null 2>&1; then
        deployment_env=$(jq -r '.deployment_env // "local"' "$CONNECTIONS_FILE" 2>/dev/null)
    else
        deployment_env="local"
    fi
    
    if [ "$deployment_env" != "docker" ]; then
        echo "Deployment environment is not Docker, skipping compose generation"
        return 0
    fi
    
    cat > "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
version: '3.8'

services:
COMPOSE_EOF
    
    # Add services from registry
    if command -v jq >/dev/null 2>&1; then
        jq -r '.services | to_entries[] | "\(.key) \(.value)"' "$CONNECTIONS_FILE" | while read service_name service_url; do
            # Extract port from URL
            port=$(echo "$service_url" | grep -o ':[0-9]*' | tr -d ':')
            
            cat >> "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
  $service_name:
    build: ./$service_name
    ports:
      - "$port:$port"
    environment:
      - NODE_ENV=production
      - PORT=$port
    networks:
      - taco_network
    depends_on:
      - database
    restart: unless-stopped

COMPOSE_EOF
        done
    fi
    
    # Add common services
    cat >> "$DOCKER_COMPOSE_FILE" << COMPOSE_EOF
  database:
    image: postgres:15
    environment:
      - POSTGRES_DB=taco_db
      - POSTGRES_USER=taco_user
      - POSTGRES_PASSWORD=taco_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - taco_network
    restart: unless-stopped

  redis:
    image: redis:7
    ports:
      - "6379:6379"
    networks:
      - taco_network
    restart: unless-stopped

networks:
  taco_network:
    driver: bridge

volumes:
  postgres_data:
COMPOSE_EOF
    
    echo "Docker Compose file generated: $DOCKER_COMPOSE_FILE"
}

# Generate Dockerfile for a service
generate_dockerfile() {
    local service_name="$1"
    local service_dir="$service_name"
    
    if [ ! -d "$service_dir" ]; then
        echo "Service directory $service_dir does not exist"
        return 1
    fi
    
    # Detect service type and generate appropriate Dockerfile
    if [ -f "$service_dir/package.json" ]; then
        # Node.js service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE \$PORT

CMD ["npm", "start"]
DOCKERFILE_EOF
    elif [ -f "$service_dir/requirements.txt" ]; then
        # Python service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE \$PORT

CMD ["python", "app.py"]
DOCKERFILE_EOF
    elif [ -f "$service_dir/go.mod" ]; then
        # Go service
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o main .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/main .

EXPOSE \$PORT

CMD ["./main"]
DOCKERFILE_EOF
    else
        echo "Unknown service type for $service_name, creating generic Dockerfile"
        cat > "$service_dir/Dockerfile" << DOCKERFILE_EOF
FROM alpine:latest

WORKDIR /app
COPY . .

EXPOSE \$PORT

CMD ["echo", "Configure this Dockerfile for your service"]
DOCKERFILE_EOF
    fi
    
    echo "Dockerfile generated for $service_name"
}

case "$1" in
    compose) generate_docker_compose ;;
    dockerfile) generate_dockerfile "$2" ;;
    all) 
        generate_docker_compose
        if command -v jq >/dev/null 2>&1; then
            jq -r '.services | keys[]' "$CONNECTIONS_FILE" | while read service; do
                generate_dockerfile "$service"
            done
        fi
        ;;
    *) echo "Usage: $0 {compose|dockerfile|all} [service_name]" ;;
esac
EOF
    chmod +x "$docker_script"
    log "INFO" "DOCKER-GEN" "Created Docker compose generator"
}