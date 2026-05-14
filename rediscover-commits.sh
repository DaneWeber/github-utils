#!/bin/bash
# Script to call GitHub API to find commits that have been removed via force push
#
# Usage: ./rediscover-commits.sh <owner> <repo> <pr_number>
# Example: ./rediscover-commits.sh DaneWeber github-utils 1
#
# Requires: jq (for JSON parsing)
# Requires: GITHUB_TOKEN environment variable (GraphQL API requires authentication)

set -e

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <owner> <repo> <pr_number>"
    echo "Example: $0 DaneWeber github-utils 1"
    echo ""
    echo "Required: GITHUB_TOKEN environment variable must be set"
    exit 1
fi

OWNER="$1"
REPO="$2"
PR_NUMBER="$3"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: sudo apt-get install jq"
    exit 1
fi

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable must be set"
    echo "Create a token at: https://github.com/settings/tokens"
    echo "The token needs 'repo' scope for private repos, or 'public_repo' for public repos"
    exit 1
fi

echo "Fetching PR timeline for $OWNER/$REPO#$PR_NUMBER..."
echo ""

# Use GraphQL API to get detailed timeline including force push events with before/after commits
GRAPHQL_QUERY=$(cat <<EOF
{
  "query": "query { repository(owner: \"$OWNER\", name: \"$REPO\") { pullRequest(number: $PR_NUMBER) { timelineItems(first: 100, itemTypes: [HEAD_REF_FORCE_PUSHED_EVENT, PULL_REQUEST_COMMIT]) { nodes { __typename ... on HeadRefForcePushedEvent { createdAt beforeCommit { oid committedDate message author { name } } afterCommit { oid committedDate message author { name } } } ... on PullRequestCommit { commit { oid committedDate message author { name } } } } } } } }"
}
EOF
)

TIMELINE_DATA=$(curl -s -H "Authorization: bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$GRAPHQL_QUERY" \
    https://api.github.com/graphql)

# Check for errors
ERROR_MSG=$(echo "$TIMELINE_DATA" | jq -r '.errors[0].message // empty')
if [ -n "$ERROR_MSG" ]; then
    echo "Error from GitHub API: $ERROR_MSG"
    exit 1
fi

# Extract force push events
FORCE_PUSH_COUNT=$(echo "$TIMELINE_DATA" | jq '[.data.repository.pullRequest.timelineItems.nodes[] | select(.__typename == "HeadRefForcePushedEvent")] | length')

if [ "$FORCE_PUSH_COUNT" -eq 0 ]; then
    echo "No force push events found in PR #$PR_NUMBER"
    echo ""
    echo "Current commits in the PR:"
    echo "=========================="
    echo ""
    
    # Show current commits
    echo "$TIMELINE_DATA" | jq -r '.data.repository.pullRequest.timelineItems.nodes[] | select(.__typename == "PullRequestCommit") | .commit | "\(.committedDate)\t\(.oid[0:7])\t\(.author.name)\t\(.message | split("\n")[0])"' | \
    while IFS=$'\t' read -r date sha author message; do
        echo "Date: $date"
        echo "Commit: $sha"
        echo "Author: $author"
        echo "Message: $message"
        echo ""
    done
else
    echo "Found $FORCE_PUSH_COUNT force push event(s)"
    echo ""
    
    # Process each force push event to find the original commits
    echo "$TIMELINE_DATA" | jq -c '.data.repository.pullRequest.timelineItems.nodes[] | select(.__typename == "HeadRefForcePushedEvent")' | \
    while read -r event; do
        FORCE_PUSH_DATE=$(echo "$event" | jq -r '.createdAt')
        BEFORE_SHA=$(echo "$event" | jq -r '.beforeCommit.oid')
        AFTER_SHA=$(echo "$event" | jq -r '.afterCommit.oid')
        
        echo "Force push at: $FORCE_PUSH_DATE"
        echo "Before: $BEFORE_SHA"
        echo "After:  $AFTER_SHA"
        echo ""
        
        # Get the PR base to compare against
        PR_URL="https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER"
        PR_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" "$PR_URL")
        BASE_SHA=$(echo "$PR_DATA" | jq -r '.base.sha')
        
        # Fetch all commits between base and the "before" SHA
        echo "Original commits (before force push to $BEFORE_SHA):"
        echo "===================================================="
        echo ""
        
        COMPARE_URL="https://api.github.com/repos/$OWNER/$REPO/compare/$BASE_SHA...$BEFORE_SHA"
        COMPARE_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" "$COMPARE_URL")
        
        # Check if the compare was successful
        COMPARE_STATUS=$(echo "$COMPARE_DATA" | jq -r '.status // empty')
        if [ "$COMPARE_STATUS" = "ahead" ] || [ "$COMPARE_STATUS" = "diverged" ]; then
            echo "$COMPARE_DATA" | jq -r '.commits[] | "\(.commit.author.date)\t\(.sha[0:7])\t\(.commit.author.name)\t\(.commit.message | split("\n")[0])"' | \
            while IFS=$'\t' read -r date sha author message; do
                echo "Date: $date"
                echo "Commit: $sha"
                echo "Author: $author"
                echo "Message: $message"
                echo ""
            done
        else
            # If compare doesn't work, try fetching the commit directly
            echo "Attempting to fetch commit $BEFORE_SHA directly..."
            echo ""
            
            COMMIT_URL="https://api.github.com/repos/$OWNER/$REPO/commits/$BEFORE_SHA"
            COMMIT_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                -H "Accept: application/vnd.github.v3+json" "$COMMIT_URL")
            
            COMMIT_MESSAGE=$(echo "$COMMIT_DATA" | jq -r '.commit.message // empty')
            if [ -n "$COMMIT_MESSAGE" ]; then
                DATE=$(echo "$COMMIT_DATA" | jq -r '.commit.author.date')
                SHA=$(echo "$COMMIT_DATA" | jq -r '.sha[0:7]')
                AUTHOR=$(echo "$COMMIT_DATA" | jq -r '.commit.author.name')
                MESSAGE=$(echo "$COMMIT_DATA" | jq -r '.commit.message | split("\n")[0]')
                
                echo "Date: $DATE"
                echo "Commit: $SHA"
                echo "Author: $AUTHOR"
                echo "Message: $MESSAGE"
                echo ""
            else
                echo "Warning: Could not fetch commit $BEFORE_SHA - it may have been garbage collected"
                echo ""
            fi
        fi
        
        echo "---"
        echo ""
    done
fi

echo "Done!"

