#!/bin/bash

# Configuration Parameters
IMAGE="markshulyhin/funcaserv"
CONTAINER_NAMES=("srv1" "srv2" "srv3")
CPU_CORES=(0 1 2)
PORT_MAPPING=(8080 8081 8082)
UPDATE_FREQUENCY=600
MONITOR_INTERVAL=30
STARTUP_DELAY=60     

# Associative Arrays for Tracking
declare -A container_launch_times
declare -A container_cpu_usage
declare -A container_status

# Function to log messages with timestamps
log_message() {
    local message="$1"
    echo "State: $message"
}

# Function to remove containers if they exist
cleanup_containers() {
    for container in "${CONTAINER_NAMES[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container"; then
            log_message "Removing existing container: $container"
            if ! docker rm -f "$container" >/dev/null 2>&1; then
                log_message "Error: Failed to remove container $container"
                return 1
            fi
        fi
    done
}

# Function to start a container with specified parameters
launch_container() {
    local name=$1
    local cpu_core=$2
    local port=$3
    if docker ps --format '{{.Names}}' | grep -q "$name"; then
        log_message "Container $name is already running."
        return 0
    fi
    log_message "Launching container: $name on CPU core $cpu_core and port $port"
    if ! docker run --name "$name" --cpuset-cpus="$cpu_core" -p "$port":8081 --rm -d "$IMAGE" >/dev/null 2>&1; then
        log_message "Error: Failed to start container $name"
        return 1
    fi
    container_launch_times["$name"]=$(date +%s)
    sleep "$STARTUP_DELAY"
}

# Function to retrieve CPU usage of a container
fetch_cpu_usage() {
    local name=$1
    docker stats "$name" --no-stream --format "{{.CPUPerc}}" | tr -d '%'
}

# Function to determine if a container is busy
is_busy() {
    local name=$1
    local usage=$(fetch_cpu_usage "$name")
    container_cpu_usage["$name"]=$usage
    if (( $(echo "$usage > 95" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

# Function to determine if a container is idle
is_idle() {
    local name=$1
    local usage=$(fetch_cpu_usage "$name")
    container_cpu_usage["$name"]=$usage
    if (( $(echo "$usage < 5" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

# Function to stop a container
stop_container() {
    local name=$1
    log_message "Stopping container: $name"
    if ! docker stop "$name" >/dev/null 2>&1; then
        log_message "Error: Failed to stop container $name"
        return 1
    fi
}

# Function to check for and apply updates
check_for_updates_and_apply() {
    log_message "Checking for updates to the container image..."
    if ! docker pull "$IMAGE" >/dev/null 2>&1; then
        log_message "Error: Failed to pull the latest image $IMAGE"
        return 1
    fi
    latest_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE" | grep -oP 'sha256:[a-f0-9]{64}')
    current_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE" | grep -oP 'sha256:[a-f0-9]{64}')
    if [[ "$latest_digest" != "$current_digest" ]]; then
        log_message "New image version detected. Updating containers..."
        for container in "${CONTAINER_NAMES[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "$container"; then
                if [[ "$container" != "srv1" && $(docker ps --format '{{.Names}}' | grep -q "srv1") ]]; then
                    stop_container "$container"
                    launch_container "$container" 1 8081
                    break
                fi
            fi
        done
        launch_container "srv2" 1 8081
        if docker ps --format '{{.Names}}' | grep -q "srv1"; then
            stop_container "srv1"
            launch_container "srv1" 0 8080
        fi
    else
        log_message "No updates available for the container image."
    fi
}

# Function to monitor and manage container states
monitor_containers() {
    for container in "${CONTAINER_NAMES[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            elapsed_time=$(( $(date +%s) - ${container_launch_times[$container]} ))
            if [[ $elapsed_time -lt $STARTUP_DELAY ]]; then
                log_message "Container $container was started, waiting for $STARTUP_DELAY seconds before checking."
                continue
            fi
            if is_busy "$container"; then
                container_status["$container"]="busy"
                log_message "Container $container is busy with CPU usage ${container_cpu_usage[$container]}%."
                if [[ "$container" == "srv1" && ${container_status["srv1"]} == "busy" && ! $(docker ps --format '{{.Names}}' | grep -q "srv2") ]]; then
                    launch_container "srv2" 1 8081
                elif [[ "$container" == "srv2" && ${container_status["srv2"]} == "busy" && ! $(docker ps --format '{{.Names}}' | grep -q "srv3") ]]; then
                    launch_container "srv3" 2 8082
                fi
            elif is_idle "$container"; then
                container_status["$container"]="idle"
                log_message "Container $container is idle with CPU usage ${container_cpu_usage[$container]}%."
                if [[ ${container_status["$container"]} == "idle" && "$container" != "srv1" ]]; then
                    stop_container "$container"
                fi
            else
                container_status["$container"]="active"
                log_message "Container $container is active with CPU usage ${container_cpu_usage[$container]}%."
            fi
        fi
    done
}

# Main Execution Loop
main() {
    cleanup_containers
    launch_container "srv1" 0 8080
    while true; do
        check_for_updates_and_apply
        monitor_containers
        sleep "$MONITOR_INTERVAL"
    done
}

# Execute the script
main
