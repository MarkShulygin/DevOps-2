#!/bin/bash

SERVER_URL="127.0.0.1/compute"

make_request() {
    curl -s -X GET "$SERVER_URL" > /dev/null
    echo "Sending request to the server"
}

while true; do
    RANDOM_DELAY=$((RANDOM % 3 + 4))
    make_request &
    sleep $RANDOM_DELAY
done

