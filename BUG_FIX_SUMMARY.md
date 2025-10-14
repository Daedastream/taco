# TACO Window Assignment Bug - Analysis and Fix

## Problem Discovered

Multiple agents were assigned the **same window number** in the tmux session, causing conflicts where agents would overwrite each other.

### Example from extracted_json.txt

```json
{"window": 5, "name": "authentication_service", ...},
{"window": 5, "name": "location_tracking_service", ...},
{"window": 5, "name": "ride_matching_engine", ...},
{"window": 5, "name": "trip_payment_service", ...},
{"window": 5, "name": "notification_service", ...},
// ... 9 more agents all assigned to window 5!
```

**Result:** 14 agents trying to use window 5 simultaneously, and 4 agents trying to use window 6.

## Root Cause

Mother (the orchestrator Claude instance) failed to increment window numbers when generating the agent specification JSON, despite the prompt template showing incremental numbering (3, 4, 5, 6, 7...).

This is a **Claude output error**, not a code bug in the TACO system itself.

## Solution Implemented

### 1. Added Validation in Parser (`src/taco/parser.py`)

Added duplicate window detection in both JSON and legacy parsers:

```python
# Validate no duplicate window numbers
if agents:
    window_numbers = [agent.window for agent in agents]
    duplicates = [w for w in set(window_numbers) if window_numbers.count(w) > 1]
    if duplicates:
        logger.error(f"❌ CRITICAL: Duplicate window numbers detected: {duplicates}")
        logger.error(f"Agents assigned to same windows:")
        for dup_window in duplicates:
            conflicting_agents = [a.name for a in agents if a.window == dup_window]
            logger.error(f"  Window {dup_window}: {', '.join(conflicting_agents)}")
        raise ValueError(
            f"Duplicate window numbers found: {duplicates}. "
            f"Each agent must have a unique window number. "
            f"Mother needs to assign sequential window numbers starting from 3."
        )
```

**Result:** System will now **fail fast** with a clear error message if Mother generates invalid window assignments, instead of silently creating broken tmux sessions.

### 2. Enhanced Mother's Prompt (`src/taco/orchestrator.py`)

Strengthened the instructions with explicit examples and warnings:

```python
⚠️ CRITICAL: Window numbers must be UNIQUE and SEQUENTIAL!
- First agent: window 3
- Second agent: window 4
- Third agent: window 5
- Fourth agent: window 6
- And so on... NEVER reuse a window number!

AGENT_SPEC_JSON_START
{
  "agents": [
    {"window": 3, "name": "project_setup", ...},
    {"window": 4, "name": "descriptive_agent_name", ...},
    {"window": 5, "name": "another_agent", ...},
    {"window": 6, "name": "yet_another_agent", ...},
    {"window": 7, "name": "integration_tester", ...}
  ]
}
AGENT_SPEC_JSON_END

⚠️ REMINDER: Each agent needs its own unique window number!
Start at 3, increment by 1 for each agent (3, 4, 5, 6, 7...).
NEVER use the same window number twice!
```

## Testing

Validated the fix works correctly:

```bash
$ python3 -c "from src.taco.parser import SpecParser; ..."
✗ Validation failed (as expected): Duplicate window numbers found: [5, 6]
❌ CRITICAL: Duplicate window numbers detected: [5, 6]
Agents assigned to same windows:
  Window 5: authentication_service, location_tracking_service, ride_matching_engine,
            trip_payment_service, notification_service, backend_api_validator,
            rider_app_core, rider_realtime_tracking, rider_app_validator,
            driver_app_core, driver_background_location, driver_app_validator,
            admin_portal, admin_validator
  Window 6: api_integration_tester, rider_app_tester, driver_app_tester, admin_tester
```

The system now **detects and rejects** invalid window assignments with clear error messages.

## Expected Behavior

### Before Fix
- Invalid JSON silently accepted
- Agents overwrite each other in tmux
- Confusing failures during execution
- Hard to diagnose root cause

### After Fix
- Invalid JSON rejected immediately
- Clear error message identifying the problem
- Lists all conflicting agents by window
- Mother gets instructive error to fix the issue

## Correct Window Assignment

For a ride-sharing app with 18 agents:

```
Window 0: Mother (orchestrator) - Reserved
Windows 1-2: Reserved for system use
Window 3: project_setup
Window 4: database_schema
Window 5: authentication_service
Window 6: location_tracking_service
Window 7: ride_matching_engine
Window 8: trip_payment_service
Window 9: notification_service
Window 10: backend_api_validator
Window 11: rider_app_core
Window 12: rider_realtime_tracking
Window 13: rider_app_validator
Window 14: driver_app_core
Window 15: driver_background_location
Window 16: driver_app_validator
Window 17: admin_portal
Window 18: admin_validator
Window 19: api_integration_tester
Window 20: rider_app_tester
Window 21: driver_app_tester
Window 22: admin_tester
Window 23: end_to_end_tester
```

**Total:** 24 tmux windows (0-23), each with a unique agent.

## Files Modified

1. **src/taco/parser.py** - Added duplicate window validation (lines 122-136, 254-268)
2. **src/taco/orchestrator.py** - Enhanced Mother's prompt with explicit examples (lines 915-971)

## Future Improvements

Potential enhancements:
1. Add window number gap detection (e.g., 3, 4, 7 - missing 5, 6)
2. Validate window numbers start at 3 (not 0, 1, 2)
3. Auto-fix: Offer to reassign window numbers sequentially
4. Pre-validation: Check spec before creating tmux windows

## Impact

✅ **Production Safety:** Invalid specs caught before creating broken tmux sessions
✅ **Developer Experience:** Clear error messages guide Mother to fix issues
✅ **System Reliability:** Fail-fast prevents confusing downstream errors
✅ **Debugging:** Explicit listing of conflicts speeds troubleshooting

---

**Fixed by:** Claude Code
**Date:** October 14, 2025
**Issue Type:** Validation Enhancement + Prompt Improvement
