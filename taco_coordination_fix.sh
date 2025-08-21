#!/usr/bin/env bash

# TACO Coordination Fix - Ensures Mother properly coordinates with named agents
# This patch improves the coordination phase to correctly map agent names to windows

# Function to enhance coordination prompt with explicit agent mapping
enhance_coordination_prompt() {
    local agent_specs=("$@")
    
    cat << 'EOF'

=== CRITICAL COORDINATION INSTRUCTIONS ===

AGENT WINDOW MAPPING (USE THESE EXACT WINDOWS):
EOF

    # Create explicit mapping for Mother
    for spec in "${agent_specs[@]}"; do
        IFS=':' read -r window_num agent_name agent_role <<< "$spec"
        echo "  Window $window_num → $agent_name: $agent_role"
    done

    cat << 'EOF'

MANDATORY COMMUNICATION PROTOCOL:
To send messages to agents, you MUST use the Bash tool with these EXACT window numbers shown above.

FOR EACH AGENT MESSAGE, EXECUTE THREE SEPARATE BASH COMMANDS:

Example for scaffold_engineer in Window 3:
1. Bash: tmux send-keys -t taco:3.0 "Your workspace is /path/to/project/scaffold. Initialize the Next.js project with TypeScript and Tailwind."
2. Bash: sleep 0.2
3. Bash: tmux send-keys -t taco:3.0 Enter

Example for database_engineer in Window 4:
1. Bash: tmux send-keys -t taco:4.0 "Your workspace is /path/to/project/database. Create the Prisma schema and migrations."
2. Bash: sleep 0.2
3. Bash: tmux send-keys -t taco:4.0 Enter

CRITICAL RULES:
✓ Use the EXACT window numbers from the mapping above
✓ NEVER send to "agent_name" window - that's Window 3, not a generic placeholder
✓ Each agent has a specific window number - use it!
✓ Execute each command separately with the Bash tool
✓ Complete all 3 steps for every message

COORDINATION SEQUENCE:
1. Create workspace directories for all agents
2. Send initial instructions to each agent WITH their workspace path
3. Monitor progress via message_relay.sh
4. Coordinate dependencies between agents
5. Validate all work with tests

BEGIN COORDINATION NOW!
Use the Bash tool to create workspaces and send instructions to each agent listed above.
EOF
}

# Function to fix the coordination message in taco/bin/taco
fix_taco_coordination() {
    local taco_file="$1"
    
    # Backup original
    cp "$taco_file" "${taco_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create patch that inserts enhanced coordination
    cat << 'PATCH' > /tmp/taco_coord_patch.sh
    # Find the line "mother_complete_msg=" and enhance the coordination section
    # This ensures Mother gets explicit window mappings
    
    # Add agent window map generation
    echo '
    # Generate explicit agent window map for Mother
    agent_window_map=""
    for spec in "${agent_specs[@]}"; do
        IFS=":" read -r window_num agent_name agent_role <<< "$spec"
        agent_window_map+="Window $window_num → $agent_name: $agent_role\n"
    done
    '
PATCH
    
    echo "Coordination fix created. To apply:"
    echo "1. Back up your current taco installation"
    echo "2. Modify the mother_complete_msg section in taco/bin/taco"
    echo "3. Ensure explicit window mappings are included"
}

# Create an improved prompt format that TACO can parse correctly
create_clean_taco_prompt() {
    cat << 'EOF' > church_taco_fixed.txt
Build a Tier-1 church website with Next.js 14, TypeScript, Tailwind CSS, Prisma ORM, SQLite/PostgreSQL, Stripe payments, Resend email, GA4 analytics, NextAuth authentication. Target WCAG 2.1 AA compliance and Lighthouse scores 95+.

AGENT_SPEC_START
AGENT:3:scaffold_engineer:Initialize Next.js 14 with TypeScript, configure Tailwind CSS and shadcn ui, setup ESLint and Prettier, create project structure and env template
AGENT:4:database_engineer:Design Prisma schema with User Campus Sermon Event Fund Donation FormSubmission models, create migrations, implement NextAuth with ADMIN STAFF VOLUNTEER VIEWER roles, build seed script
AGENT:5:frontend_engineer:Build public pages including home about plan-a-visit sermons events give watch contact prayer, implement SEO metadata, forms with zod validation, responsive design
AGENT:6:admin_engineer:Create admin dashboard with CRUD for sermons events pages forms donations settings, implement role-based access control, use shadcn ui components
AGENT:7:integration_engineer:Implement Stripe checkout and webhooks, Resend email for forms and receipts, GA4 tracking, media uploads, rate limiting, ICS calendar generation
AGENT:8:testing_engineer:Write unit tests for forms API auth, integration tests for filters exports donations, E2E tests with Playwright, validate endpoints with curl, run Lighthouse audits
AGENT:9:qa_engineer:Review design consistency, test responsive breakpoints, verify WCAG compliance, validate seed data, compile README with setup and deployment instructions
AGENT_SPEC_END

Testing: Comprehensive unit, integration, E2E tests. All endpoints validated. Lighthouse 95+.
Deployment: Complete README, env.example, seed data, Docker-ready.
EOF
    
    echo "Created fixed prompt: church_taco_fixed.txt"
}

# Main execution
echo "TACO Coordination Fix Utility"
echo "=============================="
echo
echo "This fixes the coordination issue where Mother sends messages to wrong agents."
echo
echo "Solutions:"
echo "1. Use the fixed prompt format (created as church_taco_fixed.txt)"
echo "2. Ensure agent names have no spaces or special characters"
echo "3. Use underscores in agent names (scaffold_engineer not 'scaffold engineer')"
echo
echo "Creating fixed church website prompt..."
create_clean_taco_prompt
echo
echo "To use: taco -f church_taco_fixed.txt"
echo
echo "The fix ensures:"
echo "- Agent names are properly parsed (no spaces)"
echo "- Window numbers are explicitly mapped"
echo "- Mother receives clear coordination instructions"
echo "- Each agent gets targeted messages at the correct window"