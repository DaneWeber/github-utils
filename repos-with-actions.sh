#! /bin/bash
set -euo pipefail

# Query GitHub organization for repos that have GitHub Actions enabled and output the list of repos to a file
# Usage: ./repos-with-actions.sh <org> [repo_name_filter] [output_file]
# Example: ./repos-with-actions.sh my-org utils
# Example: ./repos-with-actions.sh my-org "" all-repos-with-actions.txt
#
# Prerequisites:
# - GitHub CLI (gh) installed and authenticated: gh auth login

# Check for required arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <org> [repo_name_filter] [output_file]"
    echo "Example: $0 my-org utils"
    echo "Example: $0 my-org"
    exit 1
fi

ORG="$1"
FILTER="${2:-}"
OUTPUT_FILE="${3:-repos-with-actions-${ORG}.txt}"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

echo "Fetching repositories for organization: $ORG"
if [ -n "$FILTER" ]; then
    echo "Filter: repos containing '$FILTER' in name"
fi
echo ""

# Function to get all repos from organization
get_repos() {
    local org="$1"
    local filter="$2"
    
    echo "Fetching all repositories..." >&2
    
    # Get all repos using --paginate to handle large organizations
    local all_repos=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/orgs/${org}/repos?per_page=100&sort=full_name" \
        --paginate \
        --jq '.[] | .full_name')
    
    # Apply filter if provided
    if [ -n "$filter" ]; then
        echo "$all_repos" | grep -i "$filter"
    else
        echo "$all_repos"
    fi
}

# Function to check if a repo has Actions enabled
check_actions_enabled() {
    local repo="$1"
    
    local actions_enabled=$(gh api \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "/repos/${repo}/actions/permissions" \
        --jq '.enabled' 2>/dev/null || echo "false")
    
    echo "$actions_enabled"
}

# Get list of matching repositories
matching_repos=$(get_repos "$ORG" "$FILTER")

if [ -z "$matching_repos" ]; then
    echo "No repositories found matching the criteria."
    exit 0
fi

# Display the matching repositories
repo_count=$(echo "$matching_repos" | wc -l)
echo "Found $repo_count matching repositories:"
echo "----------------------------------------"
echo "$matching_repos"
echo "----------------------------------------"
echo ""

# Ask for confirmation
read -p "Check GitHub Actions permissions for these repos? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Check Actions status for each repo
echo ""
echo "Checking GitHub Actions status..."
echo ""

repos_with_actions=()
repos_without_actions=()

while IFS= read -r repo; do
    if [ -n "$repo" ]; then
        printf "Checking %-50s ... " "$repo"
        
        actions_enabled=$(check_actions_enabled "$repo")
        
        if [ "$actions_enabled" = "true" ]; then
            echo "✓ Actions enabled"
            repos_with_actions+=("$repo")
        else
            echo "✗ Actions disabled"
            repos_without_actions+=("$repo")
        fi
    fi
done <<< "$matching_repos"

# Display summary
echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Total repositories checked: $repo_count"
echo "With Actions enabled: ${#repos_with_actions[@]}"
echo "Without Actions enabled: ${#repos_without_actions[@]}"
echo ""

if [ ${#repos_with_actions[@]} -gt 0 ]; then
    echo "Repositories with GitHub Actions enabled:"
    printf '%s\n' "${repos_with_actions[@]}"
    
    # Save to file
    printf '%s\n' "${repos_with_actions[@]}" > "$OUTPUT_FILE"
    echo ""
    echo "Results saved to: $OUTPUT_FILE"
else
    echo "No repositories found with GitHub Actions enabled."
fi


