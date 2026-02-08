#!/bin/sh
# Generate manifest.json from all YAML capability packages

set -e

CAPABILITIES_DIR="/usr/share/nginx/html/api/capabilities/packages"
MANIFEST_FILE="/usr/share/nginx/html/api/capabilities/manifest.json"

echo "Generating capability manifest..."

# Start JSON array
echo '{' > "$MANIFEST_FILE"
echo '  "version": "1.0.0",' >> "$MANIFEST_FILE"
echo '  "updated_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'",' >> "$MANIFEST_FILE"
echo '  "packages": [' >> "$MANIFEST_FILE"

first=true
for yaml_file in "$CAPABILITIES_DIR"/*.yaml; do
    [ -f "$yaml_file" ] || continue

    filename=$(basename "$yaml_file")
    id=$(echo "$filename" | sed 's/\.yaml$//')

    # Extract version from YAML (simple grep)
    version=$(grep -m1 '^version:' "$yaml_file" | sed 's/version: *//' | tr -d '"' || echo "1.0.0")
    name=$(grep -m1 '^name:' "$yaml_file" | sed 's/name: *//' | tr -d '"' || echo "$id")

    if [ "$first" = true ]; then
        first=false
    else
        echo ',' >> "$MANIFEST_FILE"
    fi

    cat >> "$MANIFEST_FILE" << EOF
    {
      "id": "$id",
      "version": "$version",
      "name": "$name",
      "downloadUrl": "https://opencli.ai/api/capabilities/packages/$filename"
    }
EOF
done

# Close JSON array
echo '' >> "$MANIFEST_FILE"
echo '  ]' >> "$MANIFEST_FILE"
echo '}' >> "$MANIFEST_FILE"

echo "✓ Manifest generated with $(grep -c '"id"' "$MANIFEST_FILE") packages"
cat "$MANIFEST_FILE"
