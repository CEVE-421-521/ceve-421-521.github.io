#!/bin/bash

# A script to commit and push all lab repositories.
#
# USAGE:
#   ./scripts/push-labs.sh [commit message]
#
# If no commit message is provided, it will prompt for one.

LABS_DIR="../"
SEMESTER="S26"

# Get commit message
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    read -p "Enter commit message: " COMMIT_MSG
fi

if [ -z "$COMMIT_MSG" ]; then
    echo "Error: Commit message required"
    exit 1
fi

echo "Starting to push updates for all labs..."
echo "-------------------------------------------------"

for LAB_DIR in ${LABS_DIR}lab-*-${SEMESTER}; do
    LAB_NAME=$(basename "$LAB_DIR")

    if [ -d "$LAB_DIR" ]; then
        echo "=> Processing ${LAB_NAME}"
        cd "$LAB_DIR"

        # Check if there are changes
        if [ -n "$(git status --porcelain)" ]; then
            echo "   Adding and committing changes..."
            git add -A
            git commit -m "$COMMIT_MSG"

            echo "   Pushing to origin..."
            git push
        else
            echo "   No changes to commit"
        fi

        cd - > /dev/null
        echo "-------------------------------------------------"
    fi
done

echo "Lab pushing complete."
