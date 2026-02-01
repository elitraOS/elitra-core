#!/bin/bash
# Comprehensive NatSpec checker for Solidity contracts
# Usage: ./check_natspec.sh [file]

set -e

check_file() {
    local file="$1"
    local issues=0
    
    echo "=== Checking: $file ==="
    
    # Check for contract/interface/library definition
    if grep -q "^contract\|^abstract contract\|^interface\|^library" "$file"; then
        # Check for @title
        if ! grep -q "@title" "$file"; then
            echo "  ❌ Missing @title"
            ((issues++))
        else
            echo "  ✓ Has @title"
        fi
    fi
    
    # Count public/external functions
    local func_count=$(grep -c "function.*public\|function.*external" "$file" 2>/dev/null || echo "0")
    if [ "$func_count" -gt 0 ]; then
        # Count functions with @notice
        local documented=$(grep -A 5 "function.*public\|function.*external" "$file" | grep -c "@notice\|@dev" || echo "0")
        if [ "$documented" -lt "$func_count" ]; then
            echo "  ⚠️  $func_count public/external functions found, but not all have @notice"
            ((issues++))
        else
            echo "  ✓ All public/external functions documented"
        fi
    fi
    
    # Check for @param in functions with parameters
    # This is a simplified check
    local param_funcs=$(grep -B 1 "function.*(" "$file" | grep "function" | grep -v "()" | wc -l 2>/dev/null || echo "0")
    if [ "$param_funcs" -gt 0 ] 2>/dev/null; then
        local param_docs=$(grep -c "@param" "$file" 2>/dev/null || echo "0")
        if [ "$param_docs" -lt "$param_funcs" ] 2>/dev/null; then
            echo "  ⚠️  Some functions with parameters may be missing @param tags"
        fi
    fi
    
    if [ "$issues" -eq 0 ]; then
        echo "  ✓ No issues found"
    fi
    
    echo ""
    return $issues
}

if [ -n "$1" ]; then
    # Check specific file
    check_file "$1"
else
    # Check all contracts
    echo "=== NatSpec Coverage Check ==="
    echo ""
    
    total_issues=0
    for file in $(find src -name "*.sol" -type f | sort); do
        if check_file "$file"; then
            : # No issues
        else
            total_issues=$((total_issues + $?))
        fi
    done
    
    echo "=== Summary ==="
    echo "Total issues found: $total_issues"
    
    if [ "$total_issues" -eq 0 ]; then
        echo "✓ All contracts have proper NatSpec documentation!"
        exit 0
    else
        exit 1
    fi
fi
