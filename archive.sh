#!/bin/sh

help() {
    echo "\nUsage:"
    echo "\t $0 OUTPUT.tar.gz BRANCH"
    echo
}

if [ $# -ne 2 ]; then
    help
    exit 1
fi

OUTPUT=$1
BRANCH=$2

git archive --format tar.gz --output ${OUTPUT} ${BRANCH}

