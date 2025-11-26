#!/bin/bash

# Parse arguments
CONCURRENT_LIMIT=""
PROD=""
PR_NUMBER=""
BRANCH=""

# Parse all arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --prod)
      PROD="--prod"
      shift
      ;;
    --concurrent)
      CONCURRENT_LIMIT="$2"
      shift 2
      ;;
    --preview)
      # Handle preview flag for backward compatibility
      shift
      ;;
    *)
      # Handle positional arguments for backward compatibility
      if [ -z "$PR_NUMBER" ]; then
        PR_NUMBER="$1"
      elif [ -z "$BRANCH" ]; then
        BRANCH="$1"
      fi
      shift
      ;;
  esac
done

# Get all projects to deploy
ALL_PROJECTS=($(pnpm exec nx show projects --affected --withTarget vercel))
TOTAL_PROJECTS=${#ALL_PROJECTS[@]}

if [ $TOTAL_PROJECTS -eq 0 ]; then
  echo "No projects to deploy"

  # Set has-projects to false for GitHub Actions
  if [ -n "$GITHUB_ACTIONS" ]; then
    echo "has-projects=false" >> $GITHUB_OUTPUT
  fi

  exit 0
fi

echo "Found $TOTAL_PROJECTS projects to deploy: ${ALL_PROJECTS[*]}"

# Check if we're running in GitHub Actions
if [ -n "$GITHUB_ACTIONS" ]; then
  echo "Running in GitHub Actions - using matrix strategy for parallel deployment"

  # Generate matrix strategy JSON for GitHub Actions
  MATRIX_JSON=$(printf '%s\n' "${ALL_PROJECTS[@]}" | jq -R . | jq -s . | jq -c .)

  # Output the matrix for GitHub Actions to consume
  echo "projects-matrix=$MATRIX_JSON" >> $GITHUB_OUTPUT
  echo "has-projects=true" >> $GITHUB_OUTPUT

  # Also create a job summary
  {
    echo "## Vercel Deployment Plan"
    echo ""
    echo "**Projects to deploy:** $TOTAL_PROJECTS"
    echo ""
    for i in "${!ALL_PROJECTS[@]}"; do
      echo "- $((i+1)). ${ALL_PROJECTS[$i]}"
    done
    echo ""
    echo "**Deployment mode:** $(if [ -n "$PROD" ]; then echo "Production"; else echo "Preview"; fi)"
    if [ -n "$PR_NUMBER" ]; then
      echo "**PR Number:** $PR_NUMBER"
    fi
    if [ -n "$BRANCH" ]; then
      echo "**Branch:** $BRANCH"
    fi
  } >> $GITHUB_STEP_SUMMARY

  echo "Matrix strategy output generated. GitHub Actions will handle parallel deployment."
  exit 0
fi

# Fallback: If not in GitHub Actions, deploy sequentially (for local testing)
echo "Running locally - deploying projects sequentially"
echo "--------------------------------------------------"

FINAL_EXIT_CODE=0
DEPLOY_ERRORS=()

for i in "${!ALL_PROJECTS[@]}"; do
  project="${ALL_PROJECTS[$i]}"
  project_num=$((i + 1))

  echo "Starting deployment for $project at $(date '+%Y-%m-%d %H:%M:%S') ($project_num/$TOTAL_PROJECTS)"

  APP_PATH=$(if [ -d "customers/$project" ]; then
    echo "customers/$project"
  elif [ -d "apps/$project" ]; then
    echo "apps/$project"
  else
    echo ""
  fi)

  if [ -z "$APP_PATH" ]; then
    echo "❌ Project directory not found for $project"
    DEPLOY_ERRORS+=("Project directory not found for $project")
    FINAL_EXIT_CODE=1
    continue
  fi

  PROJECT_ID=$(jq -r '.projectId' "$APP_PATH/project.json" 2>/dev/null)

  if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID not found in $APP_PATH/project.json"
    DEPLOY_ERRORS+=("Project ID not found for $project")
    FINAL_EXIT_CODE=1
    continue
  fi

  # Deploy the project
  ./ci/deploy-to-vercel.sh "$PROJECT_ID" team_HleEwbs8mbEvEjDjvVoCJEoA "$APP_PATH" "$project" "$PROD" "$PR_NUMBER" "$BRANCH"

  DEPLOY_EXIT_CODE=$?
  if [ $DEPLOY_EXIT_CODE -ne 0 ]; then
    echo "❌ Failed to deploy $project"
    DEPLOY_ERRORS+=("Failed to deploy $project")
    FINAL_EXIT_CODE=1
  else
    echo "✅ Deployed $project successfully"
  fi
  echo "--------------------------------------------------"
done

if [ ${#DEPLOY_ERRORS[@]} -gt 0 ]; then
  echo "Deployment errors occurred:"
  for ERROR in "${DEPLOY_ERRORS[@]}"; do
    echo "❌ $ERROR"
  done
fi

exit $FINAL_EXIT_CODE