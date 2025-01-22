#!/bin/bash

SERVER_URL="127.0.0.1/mathcalc"

make_request() {
    curl -s -X GET "$SERVER_URL" > /dev/null
    echo "Request has been sent out"
}

while true; do
    RANDOM_DELAY=$((RANDOM % 2 + 3))
    make_request &
    sleep $RANDOM_DELAY
done

