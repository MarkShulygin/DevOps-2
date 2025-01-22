#!/bin/bash

SERVER_URL="127.0.0.1/compute"

make_request() {
    curl -s -X GET "$SERVER_URL" > /dev/null
    echo "Request was sent"
}

while true; do
    RANDOM_DELAY=$((RANDOM % 2 + 3))
    make_request &
    sleep $RANDOM_DELAY
done

