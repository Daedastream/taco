#!/usr/bin/env bash
# TACO Agent Tools Library
# Provides ready-to-use functions for agents to spin up infrastructure

# ============================
# DATABASE TOOLS
# ============================

# Spin up PostgreSQL in Docker
start_postgres() {
    local db_name="${1:-taco_db}"
    local port="${2:-5432}"
    local password="${3:-taco123}"
    
    echo "🐘 Starting PostgreSQL on port $port..."
    docker run -d \
        --name "${db_name}_postgres" \
        -e POSTGRES_PASSWORD="$password" \
        -e POSTGRES_DB="$db_name" \
        -p "$port:5432" \
        postgres:15-alpine
    
    echo "✅ PostgreSQL ready at localhost:$port"
    echo "   Database: $db_name"
    echo "   User: postgres"
    echo "   Password: $password"
    echo "   Connection: postgresql://postgres:$password@localhost:$port/$db_name"
    
    # Register in connections
    echo "{\"service\": \"postgres\", \"port\": $port, \"connection\": \"postgresql://postgres:$password@localhost:$port/$db_name\"}" >> .orchestrator/connections.json
}

# Spin up MongoDB
start_mongodb() {
    local port="${1:-27017}"
    local db_name="${2:-taco_db}"
    
    echo "🍃 Starting MongoDB on port $port..."
    docker run -d \
        --name "${db_name}_mongodb" \
        -p "$port:27017" \
        mongo:6
    
    echo "✅ MongoDB ready at mongodb://localhost:$port"
    
    # Register in connections
    echo "{\"service\": \"mongodb\", \"port\": $port, \"connection\": \"mongodb://localhost:$port\"}" >> .orchestrator/connections.json
}

# Spin up Redis
start_redis() {
    local port="${1:-6379}"
    
    echo "🔴 Starting Redis on port $port..."
    docker run -d \
        --name "taco_redis" \
        -p "$port:6379" \
        redis:7-alpine
    
    echo "✅ Redis ready at localhost:$port"
    
    # Register in connections
    echo "{\"service\": \"redis\", \"port\": $port, \"connection\": \"redis://localhost:$port\"}" >> .orchestrator/connections.json
}

# Spin up MySQL
start_mysql() {
    local db_name="${1:-taco_db}"
    local port="${2:-3306}"
    local password="${3:-taco123}"
    
    echo "🐬 Starting MySQL on port $port..."
    docker run -d \
        --name "${db_name}_mysql" \
        -e MYSQL_ROOT_PASSWORD="$password" \
        -e MYSQL_DATABASE="$db_name" \
        -p "$port:3306" \
        mysql:8
    
    echo "✅ MySQL ready at localhost:$port"
    echo "   Database: $db_name"
    echo "   User: root"
    echo "   Password: $password"
    echo "   Connection: mysql://root:$password@localhost:$port/$db_name"
    
    # Register in connections
    echo "{\"service\": \"mysql\", \"port\": $port, \"connection\": \"mysql://root:$password@localhost:$port/$db_name\"}" >> .orchestrator/connections.json
}

# ============================
# SERVER TOOLS
# ============================

# Quick Express.js API server
create_express_server() {
    local port="${1:-3000}"
    local name="${2:-api}"
    
    cat > "${name}_server.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date() });
});

// Example endpoints
app.get('/api/data', (req, res) => {
    res.json({ message: 'API is working', data: [] });
});

app.post('/api/data', (req, res) => {
    console.log('Received:', req.body);
    res.json({ success: true, received: req.body });
});

const PORT = process.env.PORT || PORT_PLACEHOLDER;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});
EOF
    
    # Replace port placeholder
    sed -i "s/PORT_PLACEHOLDER/$port/" "${name}_server.js"
    
    # Create package.json if needed
    if [ ! -f "package.json" ]; then
        npm init -y >/dev/null 2>&1
    fi
    
    # Install dependencies
    npm install express cors >/dev/null 2>&1
    
    # Start server
    echo "🚀 Starting Express server on port $port..."
    node "${name}_server.js" &
    
    echo "✅ Express API ready at http://localhost:$port"
    echo "   Health: http://localhost:$port/health"
    
    # Register in connections
    echo "{\"service\": \"${name}_api\", \"port\": $port, \"url\": \"http://localhost:$port\"}" >> .orchestrator/connections.json
}

# Quick Python Flask server
create_flask_server() {
    local port="${1:-5000}"
    local name="${2:-api}"
    
    cat > "${name}_server.py" << 'EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS
import datetime

app = Flask(__name__)
CORS(app)

@app.route('/health')
def health():
    return jsonify({
        'status': 'ok',
        'timestamp': datetime.datetime.now().isoformat()
    })

@app.route('/api/data', methods=['GET'])
def get_data():
    return jsonify({
        'message': 'API is working',
        'data': []
    })

@app.route('/api/data', methods=['POST'])
def post_data():
    data = request.json
    print(f"Received: {data}")
    return jsonify({
        'success': True,
        'received': data
    })

if __name__ == '__main__':
    app.run(port=PORT_PLACEHOLDER, debug=True)
EOF
    
    # Replace port placeholder
    sed -i "s/PORT_PLACEHOLDER/$port/" "${name}_server.py"
    
    # Install dependencies
    pip install flask flask-cors >/dev/null 2>&1
    
    # Start server
    echo "🐍 Starting Flask server on port $port..."
    python "${name}_server.py" &
    
    echo "✅ Flask API ready at http://localhost:$port"
    echo "   Health: http://localhost:$port/health"
    
    # Register in connections
    echo "{\"service\": \"${name}_api\", \"port\": $port, \"url\": \"http://localhost:$port\"}" >> .orchestrator/connections.json
}

# Quick static file server
create_static_server() {
    local port="${1:-8080}"
    local dir="${2:-.}"
    
    echo "📁 Starting static file server on port $port..."
    
    # Try Python first (usually available)
    if command -v python3 >/dev/null 2>&1; then
        cd "$dir" && python3 -m http.server "$port" &
    elif command -v python >/dev/null 2>&1; then
        cd "$dir" && python -m SimpleHTTPServer "$port" &
    elif command -v npx >/dev/null 2>&1; then
        npx http-server "$dir" -p "$port" &
    else
        echo "❌ No static server available (need python or npx)"
        return 1
    fi
    
    echo "✅ Static server ready at http://localhost:$port"
    
    # Register in connections
    echo "{\"service\": \"static_server\", \"port\": $port, \"url\": \"http://localhost:$port\"}" >> .orchestrator/connections.json
}

# ============================
# QUEUE/MESSAGE TOOLS
# ============================

# Start RabbitMQ
start_rabbitmq() {
    local port="${1:-5672}"
    local mgmt_port="${2:-15672}"
    
    echo "🐰 Starting RabbitMQ..."
    docker run -d \
        --name "taco_rabbitmq" \
        -p "$port:5672" \
        -p "$mgmt_port:15672" \
        rabbitmq:3-management-alpine
    
    echo "✅ RabbitMQ ready"
    echo "   AMQP: localhost:$port"
    echo "   Management: http://localhost:$mgmt_port (guest/guest)"
    
    # Register in connections
    echo "{\"service\": \"rabbitmq\", \"port\": $port, \"mgmt_port\": $mgmt_port}" >> .orchestrator/connections.json
}

# ============================
# SERVICE DISCOVERY
# ============================

# Find available services
discover_services() {
    echo "🔍 Discovering available services..."
    
    if [ -f ".orchestrator/connections.json" ]; then
        echo "📋 Registered services:"
        cat .orchestrator/connections.json | jq -r '.service + " on port " + (.port|tostring)' 2>/dev/null || cat .orchestrator/connections.json
    else
        echo "No services registered yet"
    fi
    
    echo ""
    echo "🐳 Docker containers:"
    docker ps --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}" 2>/dev/null || echo "Docker not available"
    
    echo ""
    echo "🔌 Listening ports:"
    if command -v lsof >/dev/null 2>&1; then
        lsof -i -P -n | grep LISTEN | grep -E ':(3000|5000|5432|27017|6379|3306|8080)' 2>/dev/null || echo "No common ports detected"
    else
        netstat -tln | grep -E ':(3000|5000|5432|27017|6379|3306|8080)' 2>/dev/null || echo "No common ports detected"
    fi
}

# Wait for service to be ready
wait_for_service() {
    local host="${1:-localhost}"
    local port="$2"
    local max_attempts="${3:-30}"
    
    echo "⏳ Waiting for $host:$port to be ready..."
    
    for i in $(seq 1 $max_attempts); do
        if nc -z "$host" "$port" 2>/dev/null; then
            echo "✅ Service at $host:$port is ready!"
            return 0
        fi
        sleep 1
    done
    
    echo "❌ Service at $host:$port failed to start after ${max_attempts}s"
    return 1
}

# ============================
# CLEANUP TOOLS
# ============================

# Stop all TACO services
cleanup_services() {
    echo "🧹 Cleaning up TACO services..."
    
    # Stop Docker containers
    docker ps -a --filter "name=taco_" -q | xargs -r docker stop 2>/dev/null
    docker ps -a --filter "name=taco_" -q | xargs -r docker rm 2>/dev/null
    
    # Kill node/python servers
    pkill -f "taco.*_server" 2>/dev/null
    
    # Clean up connections file
    > .orchestrator/connections.json
    
    echo "✅ All services cleaned up"
}

# ============================
# USAGE HELP
# ============================

show_agent_tools_help() {
    cat << 'EOF'
🛠️  TACO Agent Tools - Ready-to-use infrastructure

DATABASES:
  start_postgres [db_name] [port] [password]  - PostgreSQL database
  start_mongodb [port] [db_name]              - MongoDB database
  start_redis [port]                           - Redis cache
  start_mysql [db_name] [port] [password]     - MySQL database

SERVERS:
  create_express_server [port] [name]         - Express.js API
  create_flask_server [port] [name]           - Python Flask API
  create_static_server [port] [directory]     - Static file server

MESSAGING:
  start_rabbitmq [port] [mgmt_port]          - RabbitMQ message broker

UTILITIES:
  discover_services                           - Find running services
  wait_for_service [host] [port] [timeout]   - Wait for service
  cleanup_services                            - Stop all services

EXAMPLES:
  # Start PostgreSQL for your app
  start_postgres myapp_db 5432 secret123
  
  # Create an API server
  create_express_server 3000 api
  
  # Wait for database before connecting
  wait_for_service localhost 5432
  
  # See what's running
  discover_services

All services auto-register to .orchestrator/connections.json
EOF
}

# Export all functions so they're available to sourcing scripts
export -f start_postgres start_mongodb start_redis start_mysql
export -f create_express_server create_flask_server create_static_server
export -f start_rabbitmq discover_services wait_for_service cleanup_services
export -f show_agent_tools_help