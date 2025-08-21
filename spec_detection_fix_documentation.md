# TACO Specification Detection Fix

## Issue Summary

TACO's specification detection was failing even when Mother output contained a valid AGENT_SPEC block. The Mother output in `/Users/louisxsheid/Dev/daedastream/test/cm2/.orchestrator/mother_output_debug.txt` contained a complete specification (lines 242-280), but TACO reported it couldn't find the specification.

## Root Cause

The `check_for_complete_spec()` function in `/Users/louisxsheid/.local/taco/bin/taco` was looking for "PROJECT ANALYSIS" or "AGENT SPECIFICATION" markers that didn't exist in the actual Mother output:

```bash
local analysis_marker=$(echo "$clean_capture" | grep -n -E "(PROJECT ANALYSIS|AGENT SPECIFICATION)" | tail -1 | cut -d: -f1)

if [ -n "$analysis_marker" ]; then
    # Only process if marker found
```

This condition failed because Mother's output didn't contain these markers, causing the entire detection to fail even though the AGENT_SPEC block was present.

## Solution

The fix simplifies the detection logic to directly look for AGENT_SPEC_START and AGENT_SPEC_END markers without requiring analysis markers:

```bash
# Simply check if we have both START and END markers
if echo "$clean_capture" | grep -i "AGENT_SPEC_START" > /dev/null && \
   echo "$clean_capture" | grep -i "AGENT_SPEC_END" > /dev/null; then
    
    # Get the last AGENT_SPEC block (in case there are examples in the prompt)
    local spec_content=$(echo "$clean_capture" | awk '
        /AGENT_SPEC_START/ { delete lines; i=0; capturing=1 }
        capturing { lines[i++] = $0 }
        /AGENT_SPEC_END/ { capturing=0; for(j=0; j<i; j++) final_lines[j] = lines[j] }
        END { for(j=0; j in final_lines; j++) print final_lines[j] }
    ')
    
    # Check if we have actual agent definitions
    if echo "$spec_content" | grep -E "AGENT:[0-9]+:" > /dev/null; then
        return 0
    fi
fi
```

## Key Improvements

1. **Removed dependency on analysis markers**: The function no longer requires "PROJECT ANALYSIS" or "AGENT SPECIFICATION" markers
2. **Simplified logic**: Direct detection of AGENT_SPEC_START/END blocks
3. **Better AWK processing**: The new AWK script properly captures the last complete spec block
4. **Case-insensitive matching**: Uses `grep -i` for START/END markers

## Testing Results

The test script (`test_spec_detection.sh`) showed:
- Original function: ❌ SPECIFICATION NOT DETECTED
- Fixed function: ✅ SPECIFICATION DETECTED

## Files Modified

1. `/Users/louisxsheid/.local/taco/bin/taco` - The installed TACO binary
2. `/Users/louisxsheid/Dev/Daedastream/taco/taco/bin/taco` - The working copy

## Verification

The fix was verified using the actual Mother output that was previously failing. The new detection logic successfully identifies the AGENT_SPEC block containing 6 agents.

## Additional Notes

This fix makes TACO more robust by not assuming specific output formats from Mother. It will work as long as the specification is wrapped in AGENT_SPEC_START/END markers, regardless of what other content appears in the output.