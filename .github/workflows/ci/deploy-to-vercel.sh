#!/bin/bash

set -e

PROJECT_ID="$1"
TEAM_ID="$2"
PROD=""
OUTPUT_PATH="$3"
PROJECT_NAME="$4"
VERCEL_ENVIRONMENT="preview"
if [ "$5" == "--prod" ]; then
    PROD="--prod"
    VERCEL_ENVIRONMENT="production"
fi

if [ -z "$PROJECT_ID" ] || [ -z "$TEAM_ID" ]; then
    echo "Usage: $0 <project-id> <team-id> <output-path> <project-name> [--prod]"
    exit 1
fi

# Clean up previous builds
rm -rf "$OUTPUT_PATH/.vercel"
rm -rf ./.vercel
rm -rf "$OUTPUT_PATH/.next"
echo "Deploying project $PROJECT_ID to Vercel with environment $VERCEL_ENVIRONMENT"

# Create the ./vercel directory if it doesn't exist
mkdir -p "./.vercel"

# Use a heredoc to create the JSON structure and write it to a file
cat <<EOF > "./.vercel/project.json"
{
    "projectId": "$PROJECT_ID",
    "orgId": "$TEAM_ID",
    "settings": {}
}
EOF

cat ./.vercel/project.json

pnpm exec vercel pull --yes --environment="$VERCEL_ENVIRONMENT" --token="$VERCEL_TOKEN"

cat <<EOF > "./.vercel/project.json"
{
    "projectId": "$PROJECT_ID",
    "orgId": "$TEAM_ID",
    "settings": {
      "createdAt": $(date +%s000),
      "framework": "nextjs",
      "devCommand": null,
      "installCommand": "echo \"\"",
      "buildCommand": "nx run $PROJECT_NAME:build-next",
      "outputDirectory": "$OUTPUT_PATH/.next",
      "rootDirectory": null,
      "directoryListing": false,
      "nodeVersion": "20.x"
    }
}
EOF

rm -rf "$OUTPUT_PATH/.vercel"

if pnpm exec vercel build --output="$OUTPUT_PATH/.vercel/output" $PROD --token="$VERCEL_TOKEN"; then
    echo "Writing project.json to $OUTPUT_PATH/.vercel/project.json"
    cp "./.vercel/project.json" "$OUTPUT_PATH/.vercel/project.json"
    cp "./.vercel/.env.$VERCEL_ENVIRONMENT.local" "$OUTPUT_PATH/.vercel/.env.$VERCEL_ENVIRONMENT.local"
else
    echo "Build failed for $PROJECT_NAME"
    exit 1
fi

echo "Deploying $PROJECT_NAME to Vercel"

# Create a temporary file to store the output
temp_output_file=$(mktemp)

# Run the vercel deploy command, tee the output to both the temporary file and stdout
# Use PIPESTATUS to get the exit code of the vercel command, not tee
# Add --force to avoid interactive prompts
pnpm exec vercel deploy "$OUTPUT_PATH" --prebuilt $PROD --token="$VERCEL_TOKEN" --regions=lhr1 --force | tee "$temp_output_file"
VERCEL_EXIT_CODE=${PIPESTATUS[0]}

if [ $VERCEL_EXIT_CODE -eq 0 ]; then
    echo "Deployment successful"
    # Save the output to a file with a meaningful name
    output_file="/tmp/vercel_deploy_output_${PROJECT_NAME}.log"
    mv "$temp_output_file" "$output_file"
    echo "Deployment output saved to $output_file"

    # Check if domain attribute is set in project.json
    PROJECT_DOMAIN=$(jq -r '.domain // empty' "$OUTPUT_PATH/project.json")
    if [ -n "$PROJECT_DOMAIN" ] && [ -n "$6" ]; then
        DEPLOYMENT_URL=$(tail -n 1 "$output_file")
        ALIAS_DOMAIN="$6.$PROJECT_DOMAIN"
        CUSTOM_DOMAIN="https://$ALIAS_DOMAIN"
        echo "Setting alias for $DEPLOYMENT_URL to $ALIAS_DOMAIN"
        pnpm exec vercel alias set "$DEPLOYMENT_URL" "$ALIAS_DOMAIN" --token="$VERCEL_TOKEN" --scope="$TEAM_ID"
        # Add the custom domain with https:// to the output file
        echo -e "\n$CUSTOM_DOMAIN" >> "$output_file"
    else
        echo "Domain not set in project.json or \$6 is empty. Skipping alias creation."
    fi
else
    echo "Deployment failed"
    # Save the output to a file with a meaningful name, even if deployment failed
    output_file="/tmp/vercel_deploy_output_${PROJECT_NAME}_failed.log"
    mv "$temp_output_file" "$output_file"
    echo "Deployment output saved to $output_file"
    exit 1
fi
