#!/bin/bash

# Domain availability checker for raxol (currently using raxol.io)
# Usage: ./scripts/check_domains.sh

domains=(
    "raxol.dev"
    "raxol.io" 
    "raxol.app"
    "raxol.sh"
    "raxol.rs"
    "raxol.ai"
    "raxol.tech"
    "raxol.tools"
    "raxol.run"
    "getraxol.com"
    "tryraxol.com"
    "useraxol.com"
    "raxolapp.com"
    "raxol.xyz"
    "raxol.cc"
)

echo "🔍 Checking raxol domain availability..."
echo

for domain in "${domains[@]}"; do
    echo -n "Checking $domain... "
    
    # Try DNS lookup first (fastest)
    if nslookup "$domain" >/dev/null 2>&1; then
        echo "❌ taken"
    else
        echo "✅ AVAILABLE?"
    fi
done

echo
echo "Note: DNS lookup shows no records, but domains might still be registered."
echo "For definitive results, check manually at your preferred registrar."