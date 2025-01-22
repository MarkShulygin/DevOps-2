#!/bin/bash

container_image=("markshulyhin/funcaserv")
containers=("srv1" "srv2" "srv3")
cpu_cores=(0 1 2)
ports=(8080 8081 8082)
UPDATE_INTERVAL=600
CHECK_INTERVAL=30
START_DELAY=60

declare -A busy_time idle_time start_time
echo "Script is proccesing"

remove() {
	local name=$1
	if docker ps -a --format '{{.Names}}' | grep -q "^$name"; then
		echo "Container - $name is arleady existing so lets delete it!"
		docker rm -f "$name"
	fi
}

for name in "${containers[@]}"; do
	remove "$name"
done

start_con() {
	local name=$1
	local cpu=$2
	local port=$3
	if docker ps --format '{{.Names}}' | grep -q "$name"; then
		echo "Container $name is already working!"
		return 0;
	fi
	echo "(Launching container $name on core $cpu!)"
	if ! docker run --name "$name" --cpuset-cpus="$cpu" -p "$port":8081 --rm -d "$container_image"; then
		echo "Error: cannot launch container $name"
		return 1
	fi
	start_time[$name]=$(date +%s)
	sleep $START_DELAY
}

cpu_use() {
	local name=$1
	docker stats "$name" --no-stream --format "{{.CPUPerc}}" | tr -d '%'
}

busy() {
	local use=$(cpu_use "$1")
	echo "Using core by container $1: $use%"
	(( $(echo "$use > 95" | bc -l) ))
}

is_idle() {
	local use=$(cpu_use "$1")
	echo "Using core by container $1: $use%"
	(( $(echo "$use < 5" | bc -l) ))
}

stop_con() {
	local name=$1
	echo "Stopping container $name"
	docker stop "$name"
}

update() {
	echo "Checking for the new versions of containers"
	docker pull "$container_image"
	latest_version=$(docker inspect --format '{{.RepoDigests}}' "$container_image" | grep -oP 'sha256:[a-f0-9]{64}')
	if [[ "$latest_version" != "$(docker inspect --format '{{.RepoDigests}}' "$container_image" | grep -oP 'sha256:[a-f0-9]{64}')" ]]; then
		echo "Updating container"
		for name in "${containers[@]}"; do
			if docker ps --format '{{.Names}}' | grep -q "$name"; then
				if [[ "$name" != "srv1" && $(docker ps --format '{{.Names}}' | grep -q "srv1") ]]; then
						stop_con "$name"
						start_con "$name" 1 8081
						break
				fi
			fi
		done
		start_con "srv2" 1 8081
		if docker ps --format '{{.Names}}' | grep -q "srv1"; then
			stop_con "srv1"
			start_con "srv1" 0 8080
		fi
	else
		echo "No updates available"
		
	fi
}

start_con "srv1" 0 8080

while true; do
    update
    for i in ${!containers[@]}; do
        name=${containers[$i]}
        if docker ps --format '{{.Names}}' | grep -q "$name"; then
            elapsed_time=$(( $(date +%s) - ${start_time[$name]} ))
            if [[ $elapsed_time -lt $START_DELAY ]]; then
                echo "Container $name was started, expecting $START_DELAY before check"
                continue
            fi
            if busy "$name"; then
                busy_time[$name]=$(( ${busy_time[$name]:-0} + 1 ))
                idle_time[$name]=0
                echo "Container $name is busy already ${busy_time[$name]} minutes"
                if [[ "$name" == "srv1" && ${busy_time[$name]} -ge 2 && ! $(docker ps --format '{{.Names}}' | grep -q "srv2") ]]; then
                    start_con "srv2" 1 8081
                elif [[ "$name" == "srv2" && ${busy_time[$name]} -ge 2 && ! $(docker ps --format '{{.Names}}' | grep -q "srv3") ]]; then
                    start_con "srv3" 2 8082
                fi
            elif is_idle "$name"; then
                idle_time[$name]=$(( ${idle_time[$name]:-0} + 1 ))
                busy_time[$name]=0
                echo "Container $name is not working about ${idle_time[$name]} minutes"
                if [[ ${idle_time[$name]} -ge 2 && "$name" != "srv1" ]]; then
                    stop_con "$name"
                fi
            else
                busy_time[$name]=0
                idle_time[$name]=0
            fi
        fi
    done
    sleep $CHECK_INTERVAL
done


