# """Main orchestration logic for TACO."""

# import asyncio
# import logging
# from datetime import datetime
# from pathlib import Path
# from typing import Optional

# from .models import AgentSpec
# from .parser import SpecParser
# from .tmux_executor import TmuxExecutor

# logger = logging.getLogger(__name__)


# class TacoOrchestrator:
#     """Main orchestrator for TACO multi-agent system."""

#     def __init__(
#         self,
#         session_name: str = "taco",
#         claude_model: str = "sonnet",
#     ) -> None:
#         """
#         Initialize orchestrator.

#         Args:
#             session_name: Tmux session name
#             claude_model: Claude model to use
#         """
#         self.session_name = session_name
#         self.claude_model = claude_model
#         self.project_dir: Optional[Path] = None
#         self.agents: list[AgentSpec] = []

#         self.tmux = TmuxExecutor()
#         self.parser = SpecParser()

#     async def run(self, project_prompt: Optional[str] = None) -> None:
#         """
#         Run the orchestrator.

#         Args:
#             project_prompt: Project description (None for interactive)
#         """
#         try:
#             await self._setup()

#             if not project_prompt:
#                 project_prompt = await self._get_interactive_prompt()

#             await self._create_project_dir(project_prompt)

#             await self._start_tmux_session()

#             await self._start_mother_agent(project_prompt)

#             agents = await self._wait_for_specification()
#             self.agents = agents

#             await self._create_agents(agents)

#             await self._coordinate_agents()

#             logger.info("🎉 Orchestration complete - attaching to session")
#             await self._attach_to_session()

#         finally:
#             await self._cleanup()

#     async def _setup(self) -> None:
#         """Initialize resources."""
#         logger.info("⚡ TACO orchestrator initialized")

#     async def _get_interactive_prompt(self) -> str:
#         """Get project prompt interactively."""
#         logo = """
# \033[38;2;69;126;247m╔════════════════════════════════════════════════╗
# ║                                                ║
# ║      \033[38;2;40;90;220m████████╗\033[38;2;69;126;247m \033[38;2;60;110;235m█████╗\033[38;2;69;126;247m  \033[38;2;80;140;250m██████╗\033[38;2;69;126;247m \033[38;2;100;160;255m██████╗\033[38;2;69;126;247m         ║
# ║      \033[38;2;40;90;220m╚══██╔══╝\033[38;2;60;110;235m██╔══██╗\033[38;2;80;140;250m██╔════╝\033[38;2;100;160;255m██╔═══██╗\033[38;2;69;126;247m        ║
# ║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m███████║\033[38;2;80;140;250m██║\033[38;2;69;126;247m     \033[38;2;100;160;255m██║   ██║\033[38;2;69;126;247m        ║
# ║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m██╔══██║\033[38;2;80;140;250m██║\033[38;2;69;126;247m     \033[38;2;100;160;255m██║   ██║\033[38;2;69;126;247m        ║
# ║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m██║  ██║\033[38;2;80;140;250m╚██████╗\033[38;2;100;160;255m╚██████╔╝\033[38;2;69;126;247m        ║
# ║         \033[38;2;40;90;220m╚═╝\033[38;2;69;126;247m   \033[38;2;60;110;235m╚═╝  ╚═╝\033[38;2;80;140;250m ╚═════╝\033[38;2;69;126;247m \033[38;2;100;160;255m╚═════╝\033[38;2;69;126;247m         ║
# ║                                                ║
# ║      Tmux Agent Command Orchestrator v3.0      ║
# ║      Multi-agent AI coordination system        ║
# ║      Daedastream LLC                           ║
# ║                                                ║
# ╚════════════════════════════════════════════════╝\033[0m
# """
#         print(logo)
#         print("\n\033[1m\033[93m💬 What would you like to build?\033[0m")
#         print("\033[90m   (Describe your project, then press Enter twice)\033[0m\n")

#         lines = []
#         empty_count = 0

#         while True:
#             line = input("│  " if not lines else "│  ")
#             if not line:
#                 empty_count += 1
#                 if empty_count >= 2 or (empty_count >= 1 and lines):
#                     break
#             else:
#                 empty_count = 0
#                 lines.append(line)

#         print("\n\033[1m\033[92m🚀 Starting orchestration...\033[0m\n")
#         return "\n".join(lines)

#     async def _create_project_dir(self, prompt: str) -> None:
#         """Create project directory."""
#         project_name = "taco-project"
#         timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
#         self.project_dir = Path.cwd() / f"{project_name}-{timestamp}"
#         self.project_dir.mkdir(parents=True, exist_ok=True)

#         orchestrator_dir = self.project_dir / ".orchestrator"
#         orchestrator_dir.mkdir(exist_ok=True)

#         logger.info(f"📁 Created project directory: {self.project_dir}")

#     async def _start_tmux_session(self) -> None:
#         """Create tmux session with Mother and monitor windows."""
#         try:
#             await self.tmux._run_tmux_command(["kill-session", "-t", self.session_name])
#         except RuntimeError:
#             pass

#         await self.tmux._run_tmux_command([
#             "new-session", "-d", "-s", self.session_name,
#             "-n", "mother", "-c", str(self.project_dir)
#         ])

#         # Monitor window removed - not useful for coordination

#         logger.info(f"🖥️  Created tmux session: {self.session_name}")

#     async def _start_mother_agent(self, prompt: str) -> None:
#         """Start Mother orchestrator agent."""
#         model_flag = f"--model {self.claude_model}" if self.claude_model else ""

#         target = f"{self.session_name}:0.0"

#         await self.tmux._send_message(
#             target,
#             f"claude --dangerously-skip-permissions {model_flag}"
#         )

#         await asyncio.sleep(5)

#         await self.tmux._send_message(target, "1")
#         await asyncio.sleep(2)

#         mother_prompt = self._create_mother_prompt(prompt)
#         await self.tmux._send_message(target, mother_prompt)

#         logger.info("🤖 Mother agent awakened and awaiting spec...")

#     def _create_mother_prompt(self, user_request: str) -> str:
#         """Create Mother's initial prompt."""
#         return f"""PROJECT: {user_request}

# Design a multi-agent architecture for this project. Think like a systems architect:

# AGENT DESIGN PRINCIPLES:
# - Each agent = ONE clear domain/responsibility
# - Scale to project complexity appropriately
# - Domain-specific naming (describe what they build, not generic terms)
# - Agents work in parallel when possible (no unnecessary blocking)
# - Always end with: validator → tester (or platform_specific_tester)
# - Windows start at 3 (0=Mother, 1-2=reserved)

# EXAMPLES BY PROJECT TYPE:

# WEB APPS (Simple):
# - Todo list: setup → [database_schema + api_routes + api_validator] + [ui_components + ui_validator] + [styling] → integration_tester (8 agents, parallel)
# - Blog: setup → [content_model + markdown_parser] + [post_renderer + ui_validator] + [rss_feed] → integration_tester (7 agents, parallel)
# - Landing page: setup → [hero_section + features_section + pricing_section + contact_form in parallel] → validator → tester (7 agents, max parallel)

# WEB APPS (Complex - maximize parallelism):
# - E-commerce: setup → [product_db + cart_system] + [checkout_flow + payment_integration + payment_validator] + [order_management] + [admin_panel + admin_validator] + [email_service] → integration_tester (11 agents, parallel streams)
# - Social network: setup → [user_auth + auth_validator] + [profile_system + profile_validator] + [feed_algorithm] + [post_creator + messaging in parallel] + [notifications + media_upload in parallel] → integration_tester (11 agents, parallel)
# - SaaS dashboard: setup → [auth_system + auth_validator] + [billing_integration + billing_validator] + [data_visualization + viz_validator] + [settings_panel] + [api_client + websocket_realtime in parallel] → integration_tester (11 agents, continuous testing)

# MOBILE APPS (parallel development + testing):
# - iOS todo: setup → [swiftui_views + ui_validator] + [core_data_model + data_validator] + [sync_service + sync_tester] + [ios_notifications] → ios_integration_tester (9 agents, continuous testing)
# - Android weather: setup → [jetpack_compose_ui + ui_validator] + [location_service + weather_api_client in parallel] + [notification_service] → android_integration_tester (8 agents, parallel)
# - React Native chat: setup → [navigation_stack + chat_ui + ui_validator in parallel] + [firebase_integration + firebase_validator] + [push_notifications + media_picker in parallel] → ios_tester + android_tester (10 agents, parallel testing)

# CROSS-PLATFORM (iOS + Web - maximum parallelism):
# - Note taking app: setup → [ios_app + ios_validator] + [web_frontend + web_validator] + [sync_backend + conflict_resolution + sync_validator] + [shared_api] → ios_tester + web_tester (11 agents, parallel platforms)
# - Fitness tracker: setup → [ios_healthkit_integration + ios_validator] + [web_dashboard + web_validator] + [relay_api + analytics_engine + export_service in parallel] → ios_tester + web_tester (10 agents, parallel streams)
# - Admin panel + iOS: setup → [ios_client_app + ios_validator] + [admin_dashboard_frontend + admin_validator] + [relay_server + database_layer in parallel] + [authentication + auth_validator] → ios_tester + web_tester (11 agents, parallel validation)

# BACKEND-HEAVY (parallel endpoint development):
# - REST API: setup → [auth_middleware + auth_tester] + [user_endpoints + user_endpoint_tester] + [data_endpoints + data_endpoint_tester] + [rate_limiting + caching_layer in parallel] → integration_api_tester (10 agents, test each endpoint as built)
# - GraphQL API: setup → [schema_design] → [resolvers + resolver_tester] + [dataloaders + dataloader_tester] + [subscriptions + subscription_tester] + [auth_layer + auth_tester] → integration_tester (10 agents, continuous testing)
# - Microservices: setup → [user_service + user_service_tester] + [payment_service + payment_tester] + [notification_service + notification_tester] + [api_gateway + service_mesh in parallel] → integration_tester (10 agents, parallel services)

# REALTIME APPS (parallel streams):
# - Chat app: setup → [websocket_server + message_queue + realtime_validator] + [presence_system + frontend_client in parallel] + [message_persistence + persistence_tester] → integration_tester (9 agents, parallel)
# - Multiplayer game: setup → [game_server + server_validator] + [client_netcode + state_sync + sync_tester in parallel] + [matchmaking + leaderboard in parallel] → multiplayer_integration_tester (9 agents, parallel)
# - Collaborative editor: setup → [crdt_implementation + crdt_tester] + [websocket_transport + editor_ui in parallel] + [conflict_resolution + conflict_tester] → integration_tester (9 agents, continuous validation)

# ML/DATA (parallel pipelines):
# - ML pipeline: setup → [data_collection + data_validator] + [feature_engineering + feature_tester] → [model_training + model_validator] + [model_serving + monitoring_dashboard in parallel] → integration_tester (10 agents, validate each stage)
# - Data dashboard: setup → [data_ingestion + etl_pipeline + pipeline_validator in parallel] + [database_setup + db_tester] + [visualization_frontend + viz_validator] + [query_optimizer + query_tester] → integration_tester (11 agents, continuous testing)

# GAMES (parallel systems):
# - 2D platformer: setup → [physics_engine + physics_tester] + [sprite_renderer + rendering_tester] + [input_handler + level_editor in parallel] + [sound_manager + audio_tester] → gameplay_integration_tester (10 agents, test systems as built)
# - 3D shooter: setup → [rendering_engine + rendering_tester] + [physics_system + physics_tester] + [ai_behavior + ai_tester] + [weapon_system + networking in parallel] + [asset_pipeline + asset_validator] → gameplay_integration_tester (12 agents, parallel systems)

# FEATURE-SPECIFIC AGENTS (add when needed):
# - Authentication: auth_agent (login, signup, password reset, session management)
# - Payments: payment_agent (stripe/paypal integration, invoice generation, subscription handling)
# - Email: email_agent (templates, sending, tracking, bounce handling)
# - Search: search_agent (indexing, full-text search, autocomplete)
# - File uploads: upload_agent (S3/cloud storage, image processing, CDN integration)
# - Analytics: analytics_agent (event tracking, metrics dashboard, reports)
# - Admin tools: admin_agent (user management, content moderation, system monitoring)
# - Notifications: notification_agent (push, email, in-app, scheduling)
# - Internationalization: i18n_agent (translation system, locale handling)
# - Caching: cache_agent (Redis setup, cache strategies, invalidation)
# - Rate limiting: rate_limit_agent (API throttling, abuse prevention)
# - Logging: logging_agent (structured logs, monitoring, alerting)

# EFFICIENCY RULES - MAXIMIZE PARALLELISM:
# 1. PARALLEL EXECUTION: Agents with no dependencies work simultaneously
#    Example: frontend_agent + backend_agent + styling_agent can all work at once if setup is done
# 2. CONTINUOUS TESTING: Don't wait for all dev to finish
#    - Create validator/tester agents that test components AS they're built
#    - Backend routes get tested immediately by api_validator as backend_agent completes them
#    - Frontend components get tested by ui_validator as frontend_agent completes them
# 3. PIPELINE EFFICIENCY:
#    BAD:  setup → backend → frontend → styling → validator → tester (sequential, slow)
#    GOOD: setup → [backend + frontend + styling in parallel] → validator → tester
#    BEST: setup → [backend + backend_validator] + [frontend + ui_validator] + [styling] → integration_tester
# 4. Multiple validators/testers when beneficial:
#    - Large projects: api_validator, ui_validator, integration_validator (parallel validation)
#    - Cross-platform: ios_tester + web_tester (test both platforms simultaneously)
# 5. Clear boundaries: no overlap in responsibilities
# 6. Minimum viable agents: don't over-architect simple projects, but DO maximize parallelism

# REQUIRED: Minimum 5 agents. Design for MAXIMUM SPEED through parallel execution.

# OUTPUT FORMAT:
# Output ONLY valid JSON. Adapt agent structure to the project type:

# AGENT_SPEC_JSON_START
# {{"agents": [
#   {{"window": 3, "name": "setup_agent", "role": "Initialize [tech stack] project with dependencies and configuration", "depends_on": [], "notifies": ["next_agent"], "wait_for": []}},
#   {{"window": 4, "name": "domain_specific_agent", "role": "Specific implementation task", "depends_on": ["setup_agent"], "notifies": ["another_agent"], "wait_for": ["setup_agent"]}},
#   {{"window": 5, "name": "another_agent", "role": "Another specific task", "depends_on": ["domain_specific_agent"], "notifies": ["validator"], "wait_for": ["domain_specific_agent"]}},
#   {{"window": 6, "name": "validator", "role": "Validate code quality, type safety, architecture consistency", "depends_on": ["another_agent"], "notifies": ["tester"], "wait_for": ["another_agent"]}},
#   {{"window": 7, "name": "tester", "role": "Execute end-to-end tests and verify all functionality", "depends_on": ["validator"], "notifies": [], "wait_for": ["validator"]}}
# ]}}
# AGENT_SPEC_JSON_END

# After the JSON, output exactly: <<<DONE>>>

# Create agent specification now:"""

#     def _create_agent_prompt(self, agent: AgentSpec) -> str:
#         """Create agent-specific prompt."""
#         notifies = ", ".join(agent.notifies) if agent.notifies else "none"
#         return f"""MULTI-AGENT DEVELOPMENT SYSTEM

# You are part of a coordinated development effort with multiple Claude instances working in parallel tmux windows.

# AGENT IDENTITY:
# Name: {agent.name}
# Focus: {agent.role}
# Window: {agent.window}
# Notifies on completion: {notifies}

# WORKFLOW:
# 1. Wait for detailed task assignment from Mother (window 0)
# 2. Task messages are prefixed: [MOTHER → {agent.name}]
# 3. Tasks will include:
#    - Full project specification (architecture, ports, API routes, file structure)
#    - Your specific responsibilities and acceptance criteria
#    - Context about what other agents are doing
#    - Error handling protocol

# 4. Execute your task using all available Claude Code tools
# 5. When complete, output: TASK_COMPLETE: {agent.name}

# ERROR HANDLING:
# - If error is in YOUR domain ({agent.role}):
#   → Fix it yourself
#   → Report delay to Mother: "Delay in {agent.name}: [reason]"

# - If error is OUTSIDE your domain:
#   → DO NOT attempt to fix
#   → Report to Mother immediately: "Error outside {agent.name} domain: [details]"
#   → Mother will delegate to appropriate agent

# COORDINATION:
# - You may receive status updates from other agents
# - You may send messages to agents listed in your task spec
# - Always stay focused on your scope: {agent.role}
# - Read project spec carefully - it contains ports, routes, and file conventions

# Ready for task assignment from Mother..."""

#     async def _wait_for_specification(self, timeout: int = 180) -> list[AgentSpec]:
#         """Wait for Mother to output specification."""
#         target = f"{self.session_name}:0.0"
#         spec_file = self.project_dir / ".orchestrator" / "agent_spec.txt"

#         start_time = asyncio.get_event_loop().time()

#         while (asyncio.get_event_loop().time() - start_time) < timeout:
#             content = await self.tmux.capture_pane(target)

#             if content and "<<<DONE>>>" in content:
#                     spec_file.write_text(content)
#                     logger.info("📋 Specification received from Mother!")

#                     try:
#                         agents = self.parser.parse_spec_file(spec_file)
#                         return agents
#                     except ValueError as e:
#                         logger.error(f"Spec parsing failed: {e}")

#             await asyncio.sleep(2)

#         raise TimeoutError("Mother failed to generate specification")

#     async def _create_agents(self, agents: list[AgentSpec]) -> None:
#         """Create all agent windows."""
#         for agent in agents:
#             await self.tmux._run_tmux_command([
#                 "new-window", "-t", f"{self.session_name}:{agent.window}",
#                 "-n", agent.name, "-c", str(self.project_dir)
#             ])

#             target = f"{self.session_name}:{agent.window}.0"
#             model_flag = f"--model {self.claude_model}" if self.claude_model else ""
#             await self.tmux._send_message(
#                 target,
#                 f"claude --dangerously-skip-permissions {model_flag}"
#             )

#             await asyncio.sleep(5)
#             await self.tmux._send_message(target, "1")
#             await asyncio.sleep(2)

#             agent_prompt = self._create_agent_prompt(agent)
#             await self.tmux._send_message(target, agent_prompt)

#             logger.info(f"✨ Spawned agent: {agent.name} (window {agent.window})")

#         await asyncio.sleep(10)

#     async def _coordinate_agents(self) -> None:
#         """Send coordination instructions to Mother."""
#         agents_info = "\n".join([f"- {a.name} (window {a.window}): {a.role}" for a in self.agents])

#         coord_prompt = f"""COORDINATION MODE - ORCHESTRATOR ONLY

# ⚠️ CRITICAL: You are the ORCHESTRATOR. You do NOT write code or create files yourself.
# Your ONLY job is to delegate tasks via tmux and track progress.

# Available agents:
# {agents_info}

# PHASE 1 - PROJECT SPECIFICATION:
# First, create a detailed project specification document that includes:
# 1. Overall architecture and technology stack
# 2. Port configurations (e.g., frontend: 5173, backend: 3000, database: 5432)
# 3. API endpoint specifications (exact routes, methods, request/response formats)
# 4. File structure conventions (where each type of file goes)
# 5. Inter-agent dependencies and communication patterns
# 6. Shared constants, types, and interfaces

# PHASE 2 - DELEGATION PROTOCOL (MAXIMIZE PARALLELISM):

# ⚡ CRITICAL: Delegate to ALL agents that can work in parallel IMMEDIATELY after setup completes.
# Don't wait for one agent to finish before starting another unless there's a true dependency.

# For EACH agent, send a DETAILED task via tmux with:
# - Full project specification (architecture, ports, API routes, file structure)
# - Their specific responsibilities
# - What other agents are doing (context)
# - Expected outputs/deliverables
# - For validators/testers: "Test components AS they're completed, don't wait for everything"
# - Error handling protocol

# Example delegation format:
# tmux send-keys -t taco:3 -l "[MOTHER → agent_name]:

# PROJECT SPEC:
# - Architecture: [describe full stack]
# - Ports: frontend=5173, backend=3000, db=5432
# - API Routes: GET /api/todos, POST /api/todos, etc.
# - File Structure: src/routes/, src/lib/, src/components/

# YOUR TASK:
# [Detailed specific task with acceptance criteria]

# CONTEXT:
# - setup_agent: completed project init
# - backend_agent + frontend_agent + styling_agent: working in parallel
# - api_validator: testing backend routes as they're built
# - ui_validator: testing frontend components as they're built

# TESTING APPROACH (for validators):
# - Don't wait for all development to complete
# - Test each component/route as it's finished
# - Report issues immediately to Mother for re-delegation

# ERROR PROTOCOL:
# - Errors in your domain: fix and report delays
# - Errors outside domain: report to Mother for re-delegation

# Start working now."

# Then press Enter.

# PARALLEL DELEGATION EXAMPLE:
# After setup completes, immediately send messages to:
# - Window 4 (backend_agent): Start building API
# - Window 5 (backend_validator): Start testing APIs as backend_agent builds them
# - Window 6 (frontend_agent): Start building UI
# - Window 7 (ui_validator): Start testing UI as frontend_agent builds it
# - Window 8 (styling_agent): Start styling work

# ALL work in parallel for maximum speed!

# PHASE 3 - MONITORING:
# - Track agent completions (TASK_COMPLETE: agent_name)
# - Handle error reports and re-delegate
# - Update all agents when architecture changes
# - Coordinate inter-agent communication

# DO NOT WRITE CODE YOURSELF. Only send tmux messages to delegate.

# Start Phase 1 now - create the project specification, then begin delegating tasks."""

#         target = f"{self.session_name}:0.0"
#         await self.tmux._send_message(target, coord_prompt)

#         logger.info("🎯 Mother entering coordination mode - let's build!")


#     async def _attach_to_session(self) -> None:
#         """Attach to tmux session."""
#         import subprocess
#         subprocess.run(["tmux", "attach", "-t", self.session_name])

#     async def _cleanup(self) -> None:
#         """Clean up resources."""
#         logger.info("Cleanup complete")


"""Main orchestration logic for TACO."""

import asyncio
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional

from .models import AgentSpec
from .parser import SpecParser
from .tmux_executor import TmuxExecutor

logger = logging.getLogger(__name__)


class TacoOrchestrator:
    """Main orchestrator for TACO multi-agent system."""

    def __init__(
        self,
        session_name: str = "taco",
        claude_model: str = "sonnet",
    ) -> None:
        """
        Initialize orchestrator.

        Args:
            session_name: Tmux session name
            claude_model: Claude model to use
        """
        self.session_name = session_name
        self.claude_model = claude_model
        self.project_dir: Optional[Path] = None
        self.agents: list[AgentSpec] = []

        self.tmux = TmuxExecutor()
        self.parser = SpecParser()

    async def run(self, project_prompt: Optional[str] = None) -> None:
        """
        Run the orchestrator.

        Args:
            project_prompt: Project description (None for interactive)
        """
        try:
            await self._setup()

            if not project_prompt:
                project_prompt = await self._get_interactive_prompt()

            await self._create_project_dir(project_prompt)

            await self._start_tmux_session()

            await self._start_mother_agent(project_prompt)

            agents = await self._wait_for_specification()
            self.agents = agents

            await self._create_agents(agents)

            await self._coordinate_agents()

            logger.info("🎉 Orchestration complete - attaching to session")
            await self._attach_to_session()

        finally:
            await self._cleanup()

    async def _setup(self) -> None:
        """Initialize resources."""
        logger.info("⚡ TACO orchestrator initialized")

    async def _get_interactive_prompt(self) -> str:
        """Get project prompt interactively."""
        logo = """
\033[38;2;69;126;247m╔════════════════════════════════════════════════╗
║                                                ║
║      \033[38;2;40;90;220m████████╗\033[38;2;69;126;247m \033[38;2;60;110;235m█████╗\033[38;2;69;126;247m  \033[38;2;80;140;250m██████╗\033[38;2;69;126;247m \033[38;2;100;160;255m██████╗\033[38;2;69;126;247m         ║
║      \033[38;2;40;90;220m╚══██╔══╝\033[38;2;60;110;235m██╔══██╗\033[38;2;80;140;250m██╔════╝\033[38;2;100;160;255m██╔═══██╗\033[38;2;69;126;247m        ║
║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m███████║\033[38;2;80;140;250m██║\033[38;2;69;126;247m     \033[38;2;100;160;255m██║   ██║\033[38;2;69;126;247m        ║
║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m██╔══██║\033[38;2;80;140;250m██║\033[38;2;69;126;247m     \033[38;2;100;160;255m██║   ██║\033[38;2;69;126;247m        ║
║         \033[38;2;40;90;220m██║\033[38;2;69;126;247m   \033[38;2;60;110;235m██║  ██║\033[38;2;80;140;250m╚██████╗\033[38;2;100;160;255m╚██████╔╝\033[38;2;69;126;247m        ║
║         \033[38;2;40;90;220m╚═╝\033[38;2;69;126;247m   \033[38;2;60;110;235m╚═╝  ╚═╝\033[38;2;80;140;250m ╚═════╝\033[38;2;69;126;247m \033[38;2;100;160;255m╚═════╝\033[38;2;69;126;247m         ║
║                                                ║
║      Tmux Agent Command Orchestrator v3.0      ║
║      Multi-agent AI coordination system        ║
║      Daedastream LLC                           ║
║                                                ║
╚════════════════════════════════════════════════╝\033[0m
"""
        print(logo)
        print("\n\033[1m\033[93m💬 What would you like to build?\033[0m")
        print("\033[90m   (Describe your project, then press Enter twice)\033[0m\n")

        lines = []
        empty_count = 0

        while True:
            line = input("│  " if not lines else "│  ")
            if not line:
                empty_count += 1
                if empty_count >= 2 or (empty_count >= 1 and lines):
                    break
            else:
                empty_count = 0
                lines.append(line)

        print("\n\033[1m\033[92m🚀 Starting orchestration...\033[0m\n")
        return "\n".join(lines)

    async def _create_project_dir(self, prompt: str) -> None:
        """Create project directory."""
        project_name = "taco-project"
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        self.project_dir = Path.cwd() / f"{project_name}-{timestamp}"
        self.project_dir.mkdir(parents=True, exist_ok=True)

        orchestrator_dir = self.project_dir / ".orchestrator"
        orchestrator_dir.mkdir(exist_ok=True)

        logger.info(f"📁 Created project directory: {self.project_dir}")

    async def _start_tmux_session(self) -> None:
        """Create tmux session with Mother and monitor windows."""
        try:
            await self.tmux._run_tmux_command(["kill-session", "-t", self.session_name])
        except RuntimeError:
            pass

        await self.tmux._run_tmux_command([
            "new-session", "-d", "-s", self.session_name,
            "-n", "mother", "-c", str(self.project_dir)
        ])

        logger.info(f"🖥️  Created tmux session: {self.session_name}")

    async def _start_mother_agent(self, prompt: str) -> None:
        """Start Mother orchestrator agent."""
        model_flag = f"--model {self.claude_model}" if self.claude_model else ""

        target = f"{self.session_name}:0.0"

        await self.tmux._send_message(
            target,
            f"claude --dangerously-skip-permissions {model_flag}"
        )

        await asyncio.sleep(5)

        await self.tmux._send_message(target, "1")
        await asyncio.sleep(2)

        mother_prompt = self._create_mother_prompt(prompt)
        await self.tmux._send_message(target, mother_prompt)

        logger.info("🤖 Mother agent awakened and awaiting spec...")

    def _create_mother_prompt(self, user_request: str) -> str:
        """Create Mother's initial prompt."""
        return f"""PROJECT REQUEST: {user_request}

You are Mother, the architect of a multi-agent system. Your task is to design an optimal agent architecture for this project.

═══════════════════════════════════════════════════════════════════════
PHASE 1: DEEP ANALYSIS - Understand Before Designing
═══════════════════════════════════════════════════════════════════════

Before designing agents, analyze the project across these dimensions:

1. WORK DECOMPOSITION
   - What are the natural work units? (features, layers, systems, domains)
   - Is this a single cohesive task or multiple independent tasks?
   - Which units can be developed independently?
   - Where are the true dependencies vs assumed dependencies?
   - What work has cascading effects vs isolated impact?
   
   ASK: "Does this project benefit from parallelism, or is it naturally sequential?"
   - Single-file scripts, data transformations, simple CLIs → Usually 1 agent
   - Projects with independent components → Split for parallel development
   - Projects with tight coupling throughout → Fewer agents, more coordination

2. COMPLEXITY ASSESSMENT
   - Technical complexity: How many interconnected systems?
   - Scope complexity: How many distinct features/components?
   - Integration complexity: How tightly coupled are the pieces?
   - Scale appropriately:
     * 1 agent: Single-file scripts, data conversions, simple utilities
     * 2-3 agents: Basic CRUD apps, simple landing pages, CLI tools
     * 4-7 agents: Full-stack apps with auth, multi-page sites
     * 8-12 agents: E-commerce, SaaS dashboards, mobile apps
     * 13-20 agents: Multi-platform, microservices, complex ML pipelines

3. CRITICAL PATH ANALYSIS
   - What MUST happen sequentially? (usually just initial setup)
   - What's blocking other work? (true dependencies only)
   - What can start immediately after setup?
   - What can happen completely in parallel?

4. TESTING STRATEGY
   - When can validation begin? (often immediately, in parallel with dev)
   - What can be tested incrementally vs end-to-end?
   - Are platform-specific testers needed? (iOS, Android, Web, API)
   - Should validation happen continuously or at milestones?

═══════════════════════════════════════════════════════════════════════
PHASE 2: AGENT DESIGN PRINCIPLES
═══════════════════════════════════════════════════════════════════════

CORE PRINCIPLES:

1. SINGLE RESPONSIBILITY
   Each agent = ONE clear, bounded domain of work
   - Good: "authentication_system" (login, signup, sessions, password reset)
   - Good: "payment_integration" (Stripe setup, webhooks, invoice generation)
   - Bad: "backend" (too broad, encompasses multiple systems)
   - Bad: "helper" (vague, no clear boundary)

2. MEANINGFUL NAMING
   Agent names should describe WHAT they build, not generic roles:
   - Domain-specific: "todo_crud_api", "real_time_chat", "admin_dashboard_ui"
   - System-specific: "postgres_schema", "redis_caching", "s3_file_uploads"
   - Feature-specific: "user_authentication", "payment_processing", "email_notifications"
   - Avoid: "agent1", "backend_dev", "helper", "worker"

3. MAXIMIZE PARALLELISM - This is CRITICAL
   Default assumption: agents work in PARALLEL unless there's a true dependency
   
   Ask for each agent: "What does this TRULY depend on?"
   - Setup? (yes, almost everything depends on initial project setup)
   - Another agent's output? (only if it literally cannot start without it)
   - Shared infrastructure? (can often work in parallel with coordination)
   
   Example thinking:
   - Frontend + Backend: PARALLEL (both can start after setup)
   - API routes + Database schema: PARALLEL (can be designed together, synced later)
   - UI components + Styling: PARALLEL (styling can start with mockups)
   - Payment integration + Email system: PARALLEL (independent features)

4. CONTINUOUS VALIDATION
   Don't wait for all development to finish before testing:
   
   - Validator agents: Test code quality, architecture, patterns AS code is written
   - Tester agents: Run functional tests on completed components
   - Integration testers: Verify components work together
   
   Pattern: [dev_agent + validator_agent] → integration_tester
   Example: [api_routes + api_validator] + [ui_components + ui_validator] → integration_tester

5. APPROPRIATE GRANULARITY
   Balance between too coarse (slow, blocked) and too fine (overhead, coordination):
   
   Single agent appropriate when:
   - Task is naturally cohesive and sequential
   - No benefit from parallelism (e.g., single-file script)
   - Coordination overhead exceeds parallelism benefits
   - Project is very simple (< 100 lines of code)
   
   Multiple agents beneficial when:
   - Independent features can be built in parallel
   - Different expertise domains (frontend/backend/infra)
   - Components can be tested independently
   - Project benefits from specialized focus
   
   Too coarse: "build_entire_app" (one massive agent doing everything slowly)
   Too fine: "create_button_component", "style_button" (excessive coordination overhead)
   Right balance: 
   - Simple: "fullstack_todo_app" (one agent, cohesive)
   - Complex: "authentication_system", "product_catalog_ui", "payment_integration" (parallel specialists)

6. CLEAR COMPLETION CRITERIA
   Each agent needs unambiguous definition of "done":
   - Validator: "All code passes linting, type checking, architecture review"
   - API agent: "All endpoints implemented, documented, returning correct responses"
   - UI agent: "All components render, handle state, match design spec"

═══════════════════════════════════════════════════════════════════════
PHASE 3: ARCHITECTURAL PATTERNS (Inspiration, Not Templates)
═══════════════════════════════════════════════════════════════════════

These patterns are STARTING POINTS. Adapt them creatively to your specific project.

PATTERN: SINGLE AGENT
When: Simple, cohesive tasks without meaningful parallelism opportunities
Structure: single_agent (does everything)
Examples:
  - "CSV to JSON converter with validation"
  - "CLI calculator with history"
  - "Data scraper for single website"
  - "Basic todo app (< 200 lines total)"
Think: Is this task naturally atomic? Would splitting create unnecessary overhead?

PATTERN: SIMPLE SERIAL
When: Small projects with 2-3 distinct phases
Structure: setup → implementation → tester
Examples:
  - "Landing page with contact form": setup → page_builder → form_backend
  - "Simple REST API": setup → api_implementation → api_tester
Think: What are the 2-3 major phases? Is parallelism worth the coordination cost?

PATTERN: LAYERED PARALLEL DEVELOPMENT
When: Frontend + Backend + Infrastructure projects
Structure: setup → [infrastructure + infra_validator] + [backend + backend_validator] + [frontend + frontend_validator] → integration_tester
Think: What layers exist? Can they develop simultaneously?

PATTERN: FEATURE-BASED PARALLELISM
When: Multiple independent features
Structure: setup → [feature1 + feature1_validator] + [feature2 + feature2_validator] + [feature3 + feature3_validator] → integration_tester
Think: What features are independent? Split by feature, not layer.

PATTERN: PIPELINE STAGES
When: Data flows through sequential transformations
Structure: setup → [ingestion + ingestion_validator] → [processing + processing_validator] → [output + output_validator] → integration_tester
Think: What are the natural pipeline stages? What can be validated at each stage?

PATTERN: PLATFORM-SPECIFIC STREAMS
When: Multi-platform applications (iOS + Android + Web)
Structure: setup → [shared_backend + backend_validator] + [ios_app + ios_validator] + [android_app + android_validator] + [web_app + web_validator] → ios_tester + android_tester + web_tester
Think: What's shared? What's platform-specific? Test each platform independently.

PATTERN: MICROSERVICES PARALLEL
When: Multiple independent services
Structure: setup → [service1 + service1_validator] + [service2 + service2_validator] + [gateway + gateway_validator] → integration_tester
Think: What services are independent? What needs orchestration?

PATTERN: COMPONENT LIBRARY + CONSUMERS
When: Shared components used by multiple parts
Structure: setup → [component_library + component_validator] → [app1 + app1_validator] + [app2 + app2_validator] → integration_tester
Think: What's foundational? What consumes it? Start foundation, then parallel consumers.

═══════════════════════════════════════════════════════════════════════
PHASE 4: SPECIALIZED AGENT TYPES (Use When Relevant)
═══════════════════════════════════════════════════════════════════════

Don't force these into every project. Use them when they match project needs:

INFRASTRUCTURE:
- project_setup: Initialize project, dependencies, configuration
- database_schema: Design and implement data models
- deployment_config: Docker, CI/CD, environment setup
- monitoring_setup: Logging, metrics, alerting

BACKEND DEVELOPMENT:
- authentication_system: Login, signup, sessions, JWT, OAuth
- api_endpoints: REST/GraphQL routes and handlers
- real_time_server: WebSocket, Server-Sent Events, subscriptions
- background_jobs: Queue processing, scheduled tasks, workers
- file_storage: S3/cloud uploads, image processing, CDN

FRONTEND DEVELOPMENT:
- ui_components: Reusable React/Vue/Svelte components
- routing_navigation: App routing, deep linking, navigation flows
- state_management: Redux/Zustand/Pinia, global state, caching
- form_handling: Complex forms, validation, submission
- data_visualization: Charts, graphs, dashboards

INTEGRATIONS:
- payment_processing: Stripe/PayPal, subscriptions, invoicing
- email_service: Transactional emails, templates, delivery
- search_implementation: Full-text search, Elasticsearch, Algolia
- analytics_tracking: Event tracking, user analytics, reporting
- third_party_apis: External API integrations, rate limiting

QUALITY ASSURANCE:
- code_validator: Linting, type checking, code review, patterns
- api_validator: API contract testing, response validation
- ui_validator: Component testing, accessibility, responsiveness
- security_validator: Auth testing, injection prevention, secrets audit
- performance_validator: Load testing, optimization, profiling
- integration_tester: End-to-end testing, cross-component verification

MOBILE SPECIFIC:
- ios_native_features: HealthKit, CoreML, notifications, permissions
- android_native_features: Room, WorkManager, services
- mobile_ui: Platform-specific UI patterns, gestures
- app_store_prep: Screenshots, descriptions, compliance

SPECIALIZED:
- ml_pipeline: Data prep, training, model serving
- game_engine: Physics, rendering, input, AI
- admin_interface: User management, moderation, monitoring
- documentation: API docs, user guides, architecture docs
- migration_system: Data migration, version upgrades

═══════════════════════════════════════════════════════════════════════
PHASE 5: DEPENDENCY MAPPING
═══════════════════════════════════════════════════════════════════════

For each agent, determine:

1. HARD DEPENDENCIES (must complete before this agent starts)
   - Usually only: project_setup, foundational schemas/contracts
   - Question: "Can this agent literally not start without X being done?"

2. SOFT DEPENDENCIES (could coordinate but not blocking)
   - Shared interfaces that can be mocked or stubbed initially
   - Design contracts that can be agreed upon then built in parallel
   - These should NOT block - use coordination messages instead

3. NOTIFICATION GRAPH (who needs to know when this completes)
   - Who consumes this agent's output?
   - Who's waiting for this to finish?
   - Who needs progress updates?

═══════════════════════════════════════════════════════════════════════
PHASE 6: DESIGN YOUR ARCHITECTURE
═══════════════════════════════════════════════════════════════════════

Now, design YOUR specific agent architecture:

1. List all work that needs to be done
2. Group into logical agent responsibilities
3. Identify true dependencies (minimize these!)
4. Map out parallel work streams
5. Add validation agents where beneficial
6. Ensure testing strategy (continuous vs end-to-end)
7. Name agents descriptively based on their domain

REQUIREMENTS:
- Agent count should match project complexity (see scale guide above)
- Windows start at 3 (0=Mother, 1-2=reserved)
- Maximize parallelism when multiple agents are needed
- Simple projects with 1-2 agents don't need separate validators
- Complex projects (5+ agents) should include dedicated validation/testing
- Every agent has clear completion criteria

SCALING EXAMPLES:

1 AGENT (Simple, self-contained tasks):
- "Convert this CSV to JSON with validation"
- "Create a Python script that scrapes weather data"
- "Build a command-line calculator"
- "Write a file parser for custom format"

2-3 AGENTS (Basic applications):
- "Simple todo app": setup → fullstack_implementation → tester
- "Landing page with contact form": setup → page_builder → form_backend
- "CLI tool with config": setup → core_logic → cli_interface

4-7 AGENTS (Standard web apps):
- "Blog with admin panel": setup → [database + api_routes] + [frontend_ui] + [admin_panel] → tester
- "Todo app with auth": setup → [auth_system] + [todo_api] + [frontend] → validator → tester

8+ AGENTS (Complex applications):
- Use the full parallel architecture patterns described above
- Include dedicated validators/testers for different domains
- Maximize parallelism across independent features/platforms

═══════════════════════════════════════════════════════════════════════
OUTPUT FORMAT
═══════════════════════════════════════════════════════════════════════

Output your architecture as valid JSON:

⚠️ CRITICAL: Window numbers must be UNIQUE and SEQUENTIAL!
- First agent: window 3
- Second agent: window 4
- Third agent: window 5
- Fourth agent: window 6
- And so on... NEVER reuse a window number!

AGENT_SPEC_JSON_START
{{
  "agents": [
    {{
      "window": 3,
      "name": "project_setup",
      "role": "Initialize [tech] project with [specific dependencies and configurations]",
      "depends_on": [],
      "notifies": ["agent_that_starts_next"],
      "wait_for": []
    }},
    {{
      "window": 4,
      "name": "descriptive_agent_name",
      "role": "Specific detailed responsibility with clear boundaries",
      "depends_on": ["project_setup"],
      "notifies": ["downstream_agents"],
      "wait_for": ["project_setup"]
    }},
    {{
      "window": 5,
      "name": "another_agent",
      "role": "Another specific responsibility",
      "depends_on": ["project_setup"],
      "notifies": ["integration_tester"],
      "wait_for": ["project_setup"]
    }},
    {{
      "window": 6,
      "name": "yet_another_agent",
      "role": "Yet another specific responsibility",
      "depends_on": ["project_setup"],
      "notifies": ["integration_tester"],
      "wait_for": ["project_setup"]
    }},
    {{
      "window": 7,
      "name": "integration_tester",
      "role": "Execute end-to-end tests verifying all components work together",
      "depends_on": ["descriptive_agent_name", "another_agent", "yet_another_agent"],
      "notifies": [],
      "wait_for": ["descriptive_agent_name", "another_agent", "yet_another_agent"]
    }}
  ]
}}
AGENT_SPEC_JSON_END

⚠️ REMINDER: Each agent needs its own unique window number! Start at 3, increment by 1 for each agent (3, 4, 5, 6, 7...). NEVER use the same window number twice!

After the JSON, output exactly: <<<DONE>>>

═══════════════════════════════════════════════════════════════════════

Begin your analysis and design now."""

    def _create_agent_prompt(self, agent: AgentSpec) -> str:
        """Create agent-specific prompt."""
        notifies = ", ".join(agent.notifies) if agent.notifies else "none"
        depends_on = ", ".join(agent.depends_on) if agent.depends_on else "none"
        
        return f"""╔══════════════════════════════════════════════════════════════════════╗
║                    TACO MULTI-AGENT SYSTEM                           ║
║                  Specialized Development Agent                       ║
╚══════════════════════════════════════════════════════════════════════╝

You are a specialized development agent in a coordinated multi-agent system where
multiple Claude instances work in parallel across tmux windows to build complex
projects efficiently.

═══════════════════════════════════════════════════════════════════════
YOUR IDENTITY
═══════════════════════════════════════════════════════════════════════

Agent Name: {agent.name}
Window: {agent.window}
Core Responsibility: {agent.role}

Depends On: {depends_on}
Notifies When Done: {notifies}

═══════════════════════════════════════════════════════════════════════
OPERATIONAL PROTOCOL
═══════════════════════════════════════════════════════════════════════

PHASE 1: AWAIT TASK ASSIGNMENT
- Mother (window 0) will send you a detailed task specification
- Task messages are prefixed: [MOTHER → {agent.name}]
- Your task will include:
  * Complete project specification (architecture, tech stack, conventions)
  * Technical details (ports, API routes, file structure, shared types)
  * Your specific deliverables and acceptance criteria
  * Context about other agents' responsibilities
  * Error escalation protocol
  * Communication patterns with other agents

PHASE 2: EXECUTE YOUR TASK
- Use ALL available Claude Code tools (read, write, execute, test)
- Stay within YOUR domain: {agent.role}
- Follow project conventions specified by Mother
- Write clean, production-quality code
- Document complex logic and design decisions
- Test your work incrementally as you build

PHASE 3: HANDLE ISSUES AUTONOMOUSLY
When you encounter problems, decide:

A) PROBLEM IS WITHIN YOUR DOMAIN
   → Fix it yourself (you're capable!)
   → If it causes delays, inform Mother using Bash tool:
   ```bash
   tmux send-keys -t taco:0 -l "DELAY_REPORT: {agent.name}: [brief reason] - [estimated additional time]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
   ```
   → Continue working after fix

B) PROBLEM IS OUTSIDE YOUR DOMAIN
   Examples: Missing API endpoint, incorrect schema, broken dependency from another agent
   → DO NOT attempt to fix (stay in your lane)
   → Report to Mother immediately using Bash tool:
   ```bash
   tmux send-keys -t taco:0 -l "ERROR_REPORT: {agent.name}: [problem description] - [which agent's domain] - [blocking: YES/NO]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
   ```
   → If non-blocking: continue with other work
   → If blocking: await Mother's delegation to appropriate agent

C) PROBLEM IS SYSTEMIC (affects multiple agents)
   Examples: Architecture needs revision, tech stack change required
   → Report to Mother with recommendation using Bash tool:
   ```bash
   tmux send-keys -t taco:0 -l "SYSTEMIC_ISSUE: {agent.name}: [problem] - [impact] - [recommended solution]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
   ```
   → Await Mother's updated coordination plan

PHASE 4: COMMUNICATE PROGRESS (CRITICAL!)

You MUST proactively update Mother about your progress using the Bash tool.

⚠️ IMPORTANT: Don't just output status text - send it to Mother's window (window 0)!

Use the Bash tool to execute:
```bash
tmux send-keys -t taco:0 -l "PROGRESS: {agent.name}: [what's done] - [what's next]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

When to report:
- Major milestone reached (e.g., "3/5 components complete")
- Bug discovered and fixed
- Unexpected complexity (will take longer)
- Waiting for another agent
- Task complete

Report templates (use Bash tool to send to taco:0):

PROGRESS UPDATE:
```bash
tmux send-keys -t taco:0 -l "PROGRESS: {agent.name}: [specific accomplishment] - [next step or % done]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

BUG FOUND & FIXED:
```bash
tmux send-keys -t taco:0 -l "BUG_FIXED: {agent.name}: Found and fixed [bug description]. Impact: [scope]. No delay to timeline." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

TASK COMPLETE:
```bash
tmux send-keys -t taco:0 -l "TASK_COMPLETE: {agent.name}: [summary of deliverables and testing done]" && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

AGENT-TO-AGENT COMMUNICATION (when Mother instructs you to coordinate):
If Mother tells you to communicate with another agent in window X:
```bash
tmux send-keys -t taco:X -l "[{agent.name} → AGENT_X]: [your message about coordination, shared data, etc]" && sleep 0.2 && tmux send-keys -t taco:X Enter
```

Always copy Mother (taco:0) on important cross-agent communications!

═══════════════════════════════════════════════════════════════════════
BEST PRACTICES
═══════════════════════════════════════════════════════════════════════

1. FOCUS & BOUNDARIES
   - Your responsibility: {agent.role}
   - Stay within this scope - resist scope creep
   - If work seems outside your domain, confirm with Mother

2. QUALITY STANDARDS
   - Write production-ready code (not prototypes)
   - Follow project conventions exactly as specified
   - Include error handling and edge cases
   - Add comments for non-obvious logic
   - Think about maintainability

3. INCREMENTAL PROGRESS
   - Break your task into smaller steps
   - Test each step before moving to next
   - Report progress at meaningful milestones
   - Don't wait until end to discover issues

4. COORDINATION
   - Read ALL messages from Mother carefully
   - You may receive updates about other agents' progress
   - You may receive architecture changes - adapt quickly
   - When dependent agents complete, you'll be notified

5. COMPLETION CRITERIA
   - Your task will have clear acceptance criteria
   - Ensure ALL criteria are met before declaring completion
   - Self-review: "Would I be proud to show this code?"
   - Output TASK_COMPLETE only when truly done

6. GIT COMMITS
   ⚠️ DO NOT create git commits yourself!
   - Mother handles ALL git commits
   - Focus on writing code, not version control
   - When you complete work, report to Mother
   - Mother will create a proper commit message and commit your work

═══════════════════════════════════════════════════════════════════════
COMMUNICATION EXAMPLES (All use Bash tool to send to taco:0)
═══════════════════════════════════════════════════════════════════════

Example 1 - Progress update:
```bash
tmux send-keys -t taco:0 -l "PROGRESS: {agent.name}: Completed API endpoints for user CRUD operations (4/7 done). Next: authorization middleware." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

Example 2 - Bug found and fixed:
```bash
tmux send-keys -t taco:0 -l "BUG_FIXED: {agent.name}: Race condition in state updates - added debouncing. All tests passing now." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

Example 3 - Delay report:
```bash
tmux send-keys -t taco:0 -l "DELAY_REPORT: {agent.name}: Database connection issues - debugging pool settings. +15 min estimated." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

Example 4 - Error outside domain:
```bash
tmux send-keys -t taco:0 -l "ERROR_REPORT: {agent.name}: Frontend expects /api/products but doesn't exist. Blocking: YES. Backend_agent's domain." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

Example 5 - Completion:
```bash
tmux send-keys -t taco:0 -l "TASK_COMPLETE: {agent.name}: All 15 UI components done - responsive, accessible, tested, documented. All acceptance criteria met." && sleep 0.2 && tmux send-keys -t taco:0 Enter
```

Remember: Don't just print these in your window - use Bash tool to send them to Mother!

═══════════════════════════════════════════════════════════════════════
MINDSET
═══════════════════════════════════════════════════════════════════════

You are a SPECIALIST, not a generalist:
- Deep expertise in your domain: {agent.role}
- Trust other agents to handle their domains
- Communicate clearly and proactively
- Solve problems autonomously when possible
- Escalate when necessary (not a weakness)
- Quality over speed (but keep momentum)
- Completion means DONE, not "mostly done"

═══════════════════════════════════════════════════════════════════════

Status: READY - Awaiting task assignment from Mother (window 0)

You will receive your detailed task specification shortly. Be prepared to execute
with focus, quality, and clear communication.
"""

    async def _wait_for_specification(self, timeout: int = 180) -> list[AgentSpec]:
        """Wait for Mother to output specification."""
        target = f"{self.session_name}:0.0"
        spec_file = self.project_dir / ".orchestrator" / "agent_spec.txt"

        start_time = asyncio.get_event_loop().time()

        while (asyncio.get_event_loop().time() - start_time) < timeout:
            content = await self.tmux.capture_pane(target)

            # Look for completion marker AFTER Claude has actually output JSON
            if content and "<<<DONE>>>" in content:
                # To distinguish Mother's actual output from the example in the prompt:
                # The prompt ends with "Begin your analysis and design now."
                # Mother's ACTUAL JSON will come AFTER that line
                # So we only look for JSON that appears after that marker

                lines = content.split('\n')

                # Find where the prompt ends
                analysis_start_line = -1
                for i, line in enumerate(lines):
                    if "Begin your analysis and design now" in line:
                        analysis_start_line = i
                        break

                if analysis_start_line == -1:
                    # Prompt hasn't finished displaying yet
                    continue

                # Now look for JSON and <<<DONE>>> AFTER the analysis start
                found_json_start = False
                found_json_content = False
                found_done = False

                for i in range(analysis_start_line, len(lines)):
                    line = lines[i]

                    # Look for AGENT_SPEC_JSON_START after the prompt
                    if "AGENT_SPEC_JSON_START" in line:
                        found_json_start = True

                    # After JSON start, look for actual JSON content
                    if found_json_start:
                        stripped = line.strip()
                        if stripped.startswith('{') or ('"window"' in stripped and ':' in stripped):
                            found_json_content = True

                    # Look for <<<DONE>>> or variations (Claude sometimes abbreviates it)
                    if found_json_content and ('<<<DONE>>>' in line or '<<>>' in line or 'DONE' in line):
                        found_done = True
                        break

                # Also accept if we found JSON END marker after JSON content
                if found_json_content and not found_done:
                    for i in range(analysis_start_line, len(lines)):
                        if "AGENT_SPEC_JSON_END" in lines[i]:
                            found_done = True
                            break

                if found_json_start and found_json_content and found_done:
                    spec_file.write_text(content)
                    logger.info("📋 Specification received from Mother!")

                    try:
                        agents = self.parser.parse_spec_file(spec_file)
                        return agents
                    except ValueError as e:
                        logger.error(f"Spec parsing failed: {e}")
                        # Continue waiting, Mother might still be working

            await asyncio.sleep(2)

        raise TimeoutError("Mother failed to generate specification")

    async def _create_agents(self, agents: list[AgentSpec]) -> None:
        """Create all agent windows."""
        for agent in agents:
            await self.tmux._run_tmux_command([
                "new-window", "-t", f"{self.session_name}:{agent.window}",
                "-n", agent.name, "-c", str(self.project_dir)
            ])

            target = f"{self.session_name}:{agent.window}.0"
            model_flag = f"--model {self.claude_model}" if self.claude_model else ""
            await self.tmux._send_message(
                target,
                f"claude --dangerously-skip-permissions {model_flag}"
            )

            await asyncio.sleep(5)
            await self.tmux._send_message(target, "1")
            await asyncio.sleep(2)

            agent_prompt = self._create_agent_prompt(agent)
            await self.tmux._send_message(target, agent_prompt)

            logger.info(f"✨ Spawned agent: {agent.name} (window {agent.window})")

        await asyncio.sleep(10)

    async def _coordinate_agents(self) -> None:
        """Send coordination instructions to Mother."""
        agents_info = "\n".join([
            f"  Window {a.window}: {a.name}\n    Role: {a.role}\n    Depends: {a.depends_on}\n    Notifies: {a.notifies}"
            for a in self.agents
        ])

        coord_prompt = f"""╔══════════════════════════════════════════════════════════════════════╗
║                    COORDINATION MODE ACTIVATED                        ║
║                     Mother Orchestrator Protocol                      ║
╚══════════════════════════════════════════════════════════════════════╝

⚠️  CRITICAL ROLE DEFINITION ⚠️

You are the ORCHESTRATOR, not a developer. Your job is:
- CREATE comprehensive project specifications
- DELEGATE tasks to specialized agents via tmux
- COORDINATE agent communication and dependencies
- MONITOR progress and handle escalations
- ITERATE until project completion

You do NOT:
- Write code yourself (agents do this)
- Create files directly (agents do this)
- Execute commands in this window (agents do this in their windows)

═══════════════════════════════════════════════════════════════════════
AGENT ROSTER
═══════════════════════════════════════════════════════════════════════

{agents_info}

═══════════════════════════════════════════════════════════════════════
COORDINATION PROTOCOL
═══════════════════════════════════════════════════════════════════════

PHASE 1: CREATE COMPREHENSIVE PROJECT SPECIFICATION
───────────────────────────────────────────────────────────────────────

Before delegating ANY tasks, create a detailed master specification that all
agents will reference. This should include:

1. ARCHITECTURE OVERVIEW
   - System architecture diagram (textual)
   - Technology stack with specific versions
   - Major components and their interactions
   - Data flow between components
   - Deployment architecture

2. TECHNICAL SPECIFICATIONS
   - Port allocations (e.g., frontend: 5173, backend: 3000, db: 5432)
   - Environment variables and configuration
   - API contract specifications:
     * Endpoint routes (exact paths)
     * HTTP methods (GET, POST, PUT, DELETE)
     * Request/response schemas (with examples)
     * Authentication requirements
     * Rate limiting and caching strategies
   - Database schema (tables, relations, indexes)
   - File/folder structure conventions
   - Naming conventions (files, functions, variables)

3. SHARED CONTRACTS
   - TypeScript interfaces / types / schemas
   - Shared constants and enums
   - Error codes and handling patterns
   - API response formats
   - State management patterns

4. DEVELOPMENT STANDARDS
   - Code style and linting rules
   - Testing requirements (unit, integration, e2e)
   - Documentation standards
   - Git commit message conventions (see below)
   - Review criteria

5. GIT INITIALIZATION & WORKFLOW
   FIRST, initialize the git repository using Bash tool:
   ```bash
   cd {self.project_dir} && git init && git add .gitignore README.md && git commit -m "chore: initialize project

   - Initialize git repository
   - Add .gitignore for project type
   - Add README with project overview"
   ```

   Commit strategy:
   - Commit after each major milestone (agent completes work)
   - Use conventional commits format (see templates below)
   - Include meaningful commit messages describing WHAT and WHY
   - Commit messages should reference the agent that did the work

6. INTEGRATION POINTS
   - How frontend calls backend
   - How services communicate
   - Shared libraries or utilities
   - Third-party integrations

7. DEPENDENCY MAP
   - What must happen sequentially
   - What can happen in parallel
   - Critical path analysis
   - Blocking vs non-blocking dependencies

Save this specification to: .orchestrator/project_spec.md

PHASE 2: PARALLEL TASK DELEGATION
───────────────────────────────────────────────────────────────────────

🚨 CRITICAL COMMUNICATION PROTOCOL 🚨

To send messages to agents, you MUST use your Bash tool to execute tmux commands.
DO NOT just type tmux commands as text - they will not execute!

Every message must follow this pattern:
1. Use the Bash tool
2. Execute: tmux send-keys -t taco:[WINDOW] -l "YOUR MESSAGE"
3. Sleep 0.2 seconds (REQUIRED! tmux needs time to process)
4. Execute: tmux send-keys -t taco:[WINDOW] Enter

Without the sleep and Enter keystroke, the message won't be submitted!

Example:
```bash
tmux send-keys -t taco:3 -l "Your message here" && sleep 0.2 && tmux send-keys -t taco:3 Enter
```

🚀 CRITICAL: Maximize parallelism from the start!

After setup completes, immediately delegate to ALL agents that can start:
- Don't wait for one agent to finish before starting another
- Only true dependencies should create sequential work
- Most agents can start in parallel after initial setup

For EACH agent, send a detailed task using your Bash tool:

Use this exact pattern for EACH agent:

Step 1: Compose the message (as a bash variable for easier handling):
```bash
MESSAGE="[MOTHER → [AGENT_NAME]]:

REFERENCE: See .orchestrator/project_spec.md for complete architecture

YOUR TASK:
[Detailed, specific task description]

DELIVERABLES:
- [Specific output 1]
- [Specific output 2]
- [Specific output N]

ACCEPTANCE CRITERIA:
- [Criterion 1: testable condition]
- [Criterion 2: testable condition]

CONTEXT:
- [Other agents' roles and status]
- Your work enables: [downstream agents]
- You depend on: [upstream agents]

TECHNICAL DETAILS:
- API routes: [specific endpoints]
- File locations: [where to work]
- Dependencies: [if any]

COMMUNICATION:
- Report progress at milestones
- Report delays with estimates
- Report out-of-domain errors immediately
- Signal completion: TASK_COMPLETE: [AGENT_NAME]

ERROR PROTOCOL:
- In your domain → fix and report delays
- Outside domain → report to Mother
- Systemic issues → report with recommendations

Start immediately!"
```

Step 2: Send it using Bash tool (with required sleep!):
```bash
tmux send-keys -t taco:[WINDOW] -l "$MESSAGE" && sleep 0.2 && tmux send-keys -t taco:[WINDOW] Enter
```

The sleep 0.2 is CRITICAL - without it, the Enter key fires before the message loads!

PARALLEL DELEGATION EXAMPLE:
After setup_agent completes, use the Bash tool to send messages to ALL agents in one go:

```bash
# Send to multiple agents in parallel (note the sleep 0.2 between message and Enter!)
tmux send-keys -t taco:4 -l "MESSAGE" && sleep 0.2 && tmux send-keys -t taco:4 Enter && \
tmux send-keys -t taco:5 -l "MESSAGE" && sleep 0.2 && tmux send-keys -t taco:5 Enter && \
tmux send-keys -t taco:6 -l "MESSAGE" && sleep 0.2 && tmux send-keys -t taco:6 Enter && \
tmux send-keys -t taco:7 -l "MESSAGE" && sleep 0.2 && tmux send-keys -t taco:7 Enter
```

Or send them one at a time using separate Bash tool calls for each agent.
ALWAYS include the sleep 0.2 between message and Enter!

Maximum speed through maximum parallelism!

PHASE 3: CONTINUOUS MONITORING & COORDINATION
───────────────────────────────────────────────────────────────────────

Monitor ALL agent windows continuously. Look for:

1. COMPLETION SIGNALS
   "TASK_COMPLETE: [agent_name]"
   → Acknowledge completion
   → CREATE A GIT COMMIT for the agent's work (see commit templates below)
   → Notify dependent agents they can proceed
   → Update project status

2. PROGRESS UPDATES
   "PROGRESS: [agent_name]: [update]"
   → Track against timeline
   → Identify potential bottlenecks
   → Share relevant updates with dependent agents

3. DELAY REPORTS
   "DELAY_REPORT: [agent_name]: [reason] - [estimate]"
   → Adjust timeline expectations
   → Notify dependent agents of delay
   → Offer assistance if needed

4. ERROR REPORTS
   "ERROR_REPORT: [agent_name]: [problem] - [domain] - [blocking]"
   → Identify responsible agent
   → Delegate fix to appropriate agent
   → Provide additional context if needed
   → If blocking: prioritize resolution

5. SYSTEMIC ISSUES
   "SYSTEMIC_ISSUE: [agent_name]: [problem] - [impact] - [recommendation]"
   → Evaluate impact across all agents
   → Decide on architecture change if needed
   → Broadcast changes to ALL affected agents
   → Update project specification

PHASE 4: INTER-AGENT COORDINATION
───────────────────────────────────────────────────────────────────────

When agents need to communicate (use Bash tool for ALL with sleep 0.2):

1. DEPENDENCY COMPLETION
   When agent A finishes and agent B depends on it:

   ```bash
   tmux send-keys -t taco:[B_WINDOW] -l "[MOTHER → [B_NAME]]:
   [A_NAME] has completed. You can now proceed with [specific next step].
   Their output is located at [location].
   Reminder of your task: [brief task summary]" && \
   sleep 0.2 && \
   tmux send-keys -t taco:[B_WINDOW] Enter
   ```

2. BLOCKING ISSUES
   When agent A is blocked by agent B's incomplete work:

   ```bash
   tmux send-keys -t taco:[B_WINDOW] -l "[MOTHER → [B_NAME]]:
   PRIORITY: [A_NAME] is blocked waiting for [specific deliverable].
   Please prioritize: [specific item needed].
   Current blocker: [A_NAME] cannot proceed with [their task] until this is done." && \
   sleep 0.2 && \
   tmux send-keys -t taco:[B_WINDOW] Enter
   ```

3. ARCHITECTURE CHANGES
   When spec changes affect multiple agents:

   Broadcast to ALL affected agents using Bash tool:
   ```bash
   tmux send-keys -t taco:[WINDOW] -l "[MOTHER → ALL]:
   ARCHITECTURE UPDATE: [what changed]
   Impact on your work: [specific impact]
   New specification: [details or reference to updated spec file]
   Action required: [what they need to change]" && \
   sleep 0.2 && \
   tmux send-keys -t taco:[WINDOW] Enter
   ```

PHASE 5: ITERATION & REFINEMENT
───────────────────────────────────────────────────────────────────────

Software is rarely perfect on first pass. Manage iterations:

1. VALIDATION FAILURES
   When validator finds issues:
   → Identify which agent needs to fix
   → Send specific, actionable feedback
   → Re-run validation after fix

2. INTEGRATION ISSUES
   When integration testing reveals problems:
   → Identify root cause (which agent's domain)
   → Delegate fix with context
   → May need to coordinate multiple agents

3. REQUIREMENT CHANGES
   If project requirements evolve:
   → Update project specification
   → Notify ALL affected agents
   → Provide clear migration path

4. OPTIMIZATION PASSES
   After MVP is complete:
   → Identify optimization opportunities
   → Delegate performance improvements
   → Coordinate refactoring across agents

PHASE 6: PROJECT COMPLETION
───────────────────────────────────────────────────────────────────────

Project is complete when:
✓ All agents report TASK_COMPLETE
✓ All validators pass
✓ Integration tests pass
✓ Acceptance criteria met
✓ Documentation complete

Final steps:
1. Run comprehensive final validation
2. Generate project summary
3. Document any known issues or future work
4. Celebrate success! 🎉

═══════════════════════════════════════════════════════════════════════
BEST PRACTICES
═══════════════════════════════════════════════════════════════════════

DO:
✓ Create comprehensive specifications before delegating
✓ Delegate to all parallel agents immediately
✓ Monitor all windows continuously
✓ Provide specific, actionable feedback
✓ Coordinate dependencies explicitly
✓ Update agents when situations change
✓ Think systems-level, not code-level
✓ Celebrate agent successes

DON'T:
✗ Write code yourself (delegate it)
✗ Create files in Mother window (delegate it)
✗ Wait unnecessarily (maximize parallelism)
✗ Give vague instructions (be specific)
✗ Let agents work in silos (coordinate actively)
✗ Ignore error reports (triage immediately)
✗ Forget to update project spec (single source of truth)

═══════════════════════════════════════════════════════════════════════
COMMUNICATION TEMPLATES (Use Bash tool for ALL of these!)
═══════════════════════════════════════════════════════════════════════

INITIAL TASK DELEGATION:
```bash
tmux send-keys -t taco:[WINDOW] -l "[MOTHER → [AGENT]]: [full task specification]" && \
sleep 0.2 && \
tmux send-keys -t taco:[WINDOW] Enter
```

DEPENDENCY NOTIFICATION:
```bash
tmux send-keys -t taco:[WINDOW] -l "[MOTHER → [AGENT]]: [UPSTREAM] completed. Proceed with [NEXT_STEP]." && \
sleep 0.2 && \
tmux send-keys -t taco:[WINDOW] Enter
```

ERROR RE-DELEGATION:
```bash
tmux send-keys -t taco:[WINDOW] -l "[MOTHER → [AGENT]]: [REPORTING_AGENT] found issue in your domain: [DETAILS]. Please fix: [SPECIFICS]." && \
sleep 0.2 && \
tmux send-keys -t taco:[WINDOW] Enter
```

PRIORITY UPDATE:
```bash
tmux send-keys -t taco:[WINDOW] -l "[MOTHER → [AGENT]]: PRIORITY: [BLOCKED_AGENT] needs [DELIVERABLE]. Please prioritize." && \
sleep 0.2 && \
tmux send-keys -t taco:[WINDOW] Enter
```

SPEC UPDATE:
```bash
tmux send-keys -t taco:[WINDOW] -l "[MOTHER → [AGENT]]: SPEC UPDATE: [CHANGES]. Impact on you: [SPECIFIC]. Action: [REQUIRED_CHANGES]." && \
sleep 0.2 && \
tmux send-keys -t taco:[WINDOW] Enter
```

⚠️ CRITICAL: Always use the Bash tool, always include sleep 0.2, and always include the Enter keystroke!

═══════════════════════════════════════════════════════════════════════
GIT COMMIT WORKFLOW (CRITICAL!)
═══════════════════════════════════════════════════════════════════════

WHEN TO COMMIT:
- After agent reports TASK_COMPLETE
- After major milestones (e.g., "API endpoints done", "UI components complete")
- After bug fixes that agents report
- After integration between components works
- Before major architecture changes

HOW TO COMMIT:
Use the Bash tool to execute git commands in the project directory:

```bash
cd {self.project_dir} && git add . && git commit -m "type(scope): description

Detailed explanation of what changed and why.

Agent: [agent_name]
Deliverables:
- [specific item 1]
- [specific item 2]
- [specific item 3]"
```

COMMIT MESSAGE FORMAT (Conventional Commits):

Types:
- feat: New feature (e.g., "feat(api): add user authentication endpoints")
- fix: Bug fix (e.g., "fix(ui): resolve mobile responsiveness issue")
- docs: Documentation (e.g., "docs(readme): add API usage examples")
- style: Code style changes (e.g., "style(backend): apply ESLint fixes")
- refactor: Code refactoring (e.g., "refactor(db): optimize query performance")
- test: Adding tests (e.g., "test(api): add integration tests for auth")
- chore: Maintenance (e.g., "chore(deps): update dependencies")
- perf: Performance improvements (e.g., "perf(frontend): optimize bundle size")

COMMIT TEMPLATES:

Initial setup:
```bash
cd {self.project_dir} && git add . && git commit -m "chore: initialize project structure

Setup initial project with configuration and dependencies.

Agent: project_setup
Deliverables:
- Project structure created
- Dependencies installed
- Configuration files added
- README initialized"
```

Feature completion:
```bash
cd {self.project_dir} && git add . && git commit -m "feat(backend): implement REST API endpoints

Add CRUD endpoints for user management with authentication.

Agent: backend_api
Deliverables:
- GET /api/users - list users
- POST /api/users - create user
- PUT /api/users/:id - update user
- DELETE /api/users/:id - delete user
- JWT authentication middleware
- Request validation"
```

Bug fix:
```bash
cd {self.project_dir} && git add . && git commit -m "fix(frontend): resolve state synchronization issue

Fixed race condition in WebSocket updates causing stale data.

Agent: frontend_ui
Impact: Resolved real-time update lag
Testing: All integration tests passing"
```

Integration:
```bash
cd {self.project_dir} && git add . && git commit -m "feat(integration): connect frontend to backend API

Integrated React frontend with Express backend.

Agent: integration_tester
Deliverables:
- API client configured
- CORS settings validated
- Auth flow end-to-end working
- Error handling implemented"
```

Testing completion:
```bash
cd {self.project_dir} && git add . && git commit -m "test(e2e): add end-to-end test suite

Comprehensive E2E tests for critical user flows.

Agent: integration_tester
Coverage:
- User authentication flow
- Data CRUD operations
- Real-time updates
- Error scenarios
All tests passing ✓"
```

⚠️ IMPORTANT:
- Commit AFTER agent completes, not before
- Use git add . to stage all changes
- Include the agent name in the commit body
- Make messages descriptive and actionable
- Use conventional commit format for consistency

═══════════════════════════════════════════════════════════════════════

Status: COORDINATION MODE ACTIVE

Begin with Phase 1: Create your comprehensive project specification, then proceed
with parallel task delegation. Remember: You orchestrate, agents execute.

Let's build something amazing! 🚀
"""

        target = f"{self.session_name}:0.0"
        await self.tmux._send_message(target, coord_prompt)

        logger.info("🎯 Mother entering coordination mode - maximum efficiency engaged!")


    async def _attach_to_session(self) -> None:
        """Attach to tmux session."""
        import subprocess
        subprocess.run(["tmux", "attach", "-t", self.session_name])

    async def _cleanup(self) -> None:
        """Clean up resources."""
        logger.info("Cleanup complete")