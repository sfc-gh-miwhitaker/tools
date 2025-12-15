#!/bin/bash
# Fix private key format in .env.local
# Run this if you're getting "JWT token is invalid" errors

set -e

echo "=========================================="
echo "Private Key Format Fixer"
echo "=========================================="
echo ""

# Check if rsa_key.pem exists
if [ ! -f "rsa_key.pem" ]; then
    echo "❌ Error: rsa_key.pem not found"
    echo "   Please run ./tools/01_setup.sh first"
    exit 1
fi

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "❌ Error: .env.local not found"
    echo "   Please run ./tools/01_setup.sh first"
    exit 1
fi

echo "Fixing private key format in .env.local..."

# Backup existing .env.local
cp .env.local .env.local.bak
echo "✅ Backed up .env.local to .env.local.bak"

# Extract properly formatted private key (single line with \n escape sequences)
PRIVATE_KEY_ESCAPED=$(awk 'NR>1{printf "\\n"}{printf "%s",$0}' rsa_key.pem)

# Use a temporary file to avoid sed platform differences
temp_file=$(mktemp)
while IFS= read -r line; do
    if [[ $line == REACT_APP_SNOWFLAKE_PRIVATE_KEY=* ]]; then
        echo "REACT_APP_SNOWFLAKE_PRIVATE_KEY=\"$PRIVATE_KEY_ESCAPED\""
    else
        echo "$line"
    fi
done < .env.local > "$temp_file"

# Replace original file
mv "$temp_file" .env.local

echo "✅ Fixed private key format"
echo ""

# Verify
if grep -q "BEGIN PRIVATE KEY" .env.local && grep -q "END PRIVATE KEY" .env.local; then
    # Check for \n escape sequences
    if grep "REACT_APP_SNOWFLAKE_PRIVATE_KEY" .env.local | grep -q '\\n'; then
        echo "✅ Verification passed:"
        echo "   - Private key has BEGIN/END markers"
        echo "   - Uses proper \\n escape sequences"
        echo ""
        echo "🎉 Your .env.local should now work correctly!"
        echo "   Try running: npm start"
    else
        echo "⚠️  Warning: Private key may still need manual adjustment"
        echo "   Expected format: REACT_APP_SNOWFLAKE_PRIVATE_KEY=\"-----BEGIN PRIVATE KEY-----\\nMIIE...\\n-----END PRIVATE KEY-----\""
    fi
else
    echo "❌ Verification failed: Private key markers not found"
    echo "   Your backup is at .env.local.bak"
fi
echo ""

