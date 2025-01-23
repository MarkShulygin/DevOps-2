#!/bin/bash

IMAGE_NAME="markshulyhin/funcaserv"
CONTAINERS=("srv1" "srv2" "srv3")
CPU_CORES=(0 1 2)
PORTS=(8080 8081 8082)
UPDATE_INTERVAL=600     
CHECK_INTERVAL=30    
START_DELAY=60


declare -A container_start_time
declare -A container_busy_time
declare -A container_idle_time


remove_existing_containers() {
    for container in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container"; then
            echo "Removing existing container: $container"
            if ! docker rm -f "$container" >/dev/null 2>&1; then
                log_error "Failed to remove container: $container"
                return 1
            fi
        fi
    done
}

start_container() {
    local container_name=\$1
    local cpu_core=\$2
    local port=\$3
    if docker ps --format '{{.Names}}' | grep -q "$container_name"; then
        echo "Container $container_name is already running."
        return 0
    fi
    echo "Starting container: $container_name on CPU core $cpu_core and port $port"
    if ! docker run --name "$container_name" --cpuset-cpus="$cpu_core" -p "$port":8081 --rm -d "$IMAGE_NAME" >/dev/null 2>&1; then
        log_error "Failed to start container: $container_name"
        return 1
    fi
    container_start_time["$container_name"]=$(date +%s)
    sleep "$START_DELAY"
}

get_container_cpu_usage() {
    local container_name=\$1
    docker stats "$container_name" --no-stream --format "{{.CPUPerc}}" | tr -d '%'
}

is_container_busy() {
    local container_name=\$1
    local usage=$(get_container_cpu_usage "$container_name")
    echo "Container $container_name CPU usage: $usage%"
    if (( $(echo "$usage > 95" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

is_container_idle() {
    local container_name=\$1
    local usage=$(get_container_cpu_usage "$container_name")
    echo "Container $container_name CPU usage: $usage%"
    if (( $(echo "$usage < 5" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

stop_container() {
    local container_name=\$1
    echo "Stopping container: $container_name"
    if ! docker stop "$container_name" >/dev/null 2>&1; then
        log_error "Failed to stop container: $container_name"
        return 1
    fi
}

check_for_updates() {
    echo "Checking for updates to the container image..."
    if ! docker pull "$IMAGE_NAME" >/dev/null 2>&1; then
        log_error "Failed to pull the latest image: $IMAGE_NAME"
        return 1
    fi
    latest_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE_NAME" | grep -oP 'sha256:[a-f0-9]{64}')
    current_digest=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE_NAME" | grep -oP 'sha256:[a-f0-9]{64}')
    if [[ "$latest_digest" != "$current_digest" ]]; then
        echo "New image version detected. Updating containers..."
        for container in "${CONTAINERS[@]}"; do
            if docker ps --format '{{.Names}}' | grep -q "$container"; then
                if [[ "$container" != "srv1" && $(docker ps --format '{{.Names}}' | grep -q "srv1") ]]; then
                    stop_container "$container"
                    start_container "$container" 1 8081
                    break
                fi
            fi
        done
        start_container "srv2" 1 8081
        if docker ps --format '{{.Names}}' | grep -q "srv1"; then
            stop_container "srv1"
            start_container "srv1" 0 8080
        fi
    else
        echo "No updates available for the container image."
    fi
}

manage_container_state() {
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            elapsed_time=$(( $(date +%s) - ${container_start_time[$container]} ))
            if [[ $elapsed_time -lt $START_DELAY ]]; then
                echo "Container $container was started, waiting for $START_DELAY seconds before checking."
                continue
            fi
            if is_container_busy "$container"; then
                container_busy_time["$container"]=$(( ${container_busy_time[$container]:-0} + 1 ))
                container_idle_time["$container"]=0
                echo "Container $container is busy for ${container_busy_time[$container]} minutes."
                if [[ "$container" == "srv1" && ${container_busy_time["srv1"]} -ge 2 && ! $(docker ps --format '{{.Names}}' | grep -q "srv2") ]]; then
                    start_container "srv2" 1 8081
                elif [[ "$container" == "srv2" && ${container_busy_time["srv2"]} -ge 2 && ! $(docker ps --format '{{.Names}}' | grep -q "srv3") ]]; then
                    start_container "srv3" 2 8082
                fi
            elif is_container_idle "$container"; then
                container_idle_time["$container"]=$(( ${container_idle_time["$container"]: -0} + 1 ))
                container_busy_time["$container"]=0
                echo "Container $container is idle for ${container_idle_time["$container"]} minutes."
                if [[ ${container_idle_time["$container"]} -ge 2 && "$container" != "srv1" ]]; then
                    stop_container "$container"
                fi
            else
                container_busy_time["$container"]=0
                container_idle_time["$container"]=0
            fi
        fi
    done
}

log_error() {
    echo "\$1" >&2
    logger "\$1"
}

cleanup_resources() {
    echo "Cleaning up containers..."
    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            stop_container "$container"
        fi
    done
}

trap cleanup_resources EXIT

main() {
    remove_existing_containers
    start_container "srv1" 0 8080
    while true; do
        check_for_updates
        manage_container_state
        sleep "$CHECK_INTERVAL"
    done
}

main
