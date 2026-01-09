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

for i in 01 02 03 04 05 06 07 08 09 10; do
    LAB_DIR="${LABS_DIR}lab-${i}-${SEMESTER}"

    if [ -d "$LAB_DIR" ]; then
        echo "=> Processing lab-${i}-${SEMESTER}"
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
    else
        echo "=> Skipping lab-${i}-${SEMESTER} (directory not found)"
        echo "-------------------------------------------------"
    fi
done

echo "Lab pushing complete."
