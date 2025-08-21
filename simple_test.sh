#\!/bin/bash

test_logic() {
    collecting_role=false
    echo "Initial collecting_role: '$collecting_role'"
    
    if [ "$collecting_role" = true ]; then
        echo "ERROR: This should not execute\!"
    else
        echo "GOOD: collecting_role is false as expected"
    fi
    
    collecting_role=true
    echo "After setting to true: '$collecting_role'"
    
    if [ "$collecting_role" = true ]; then
        echo "GOOD: Now it's true"
    else
        echo "ERROR: This should not execute\!"
    fi
}

test_logic
