#!/bin/bash

# Get the user, remote host, source port, target host, target port, certificate path, remote port, and sleep duration from input or environment variables
USER="${1:-$USER}"
REMOTE_HOST="${2:-$REMOTE_HOST}"
SOURCE_PORT="${3:-$SOURCE_PORT}"
TARGET_HOST="${4:-$TARGET_HOST}"
TARGET_PORT="${5:-$TARGET_PORT}"
CERTIFICATE_PATH="${6:-$CERTIFICATE_PATH}"
REMOTE_PORT="${7:-$REMOTE_PORT}"
SLEEP_DURATION="${8:-5}"
KEEPALIVE_INTERVAL="${9:-${KEEPALIVE_INTERVAL:-300}}"  # Keepalive interval in seconds (default 5 minutes)

# Set default value of remote port if not defined
REMOTE_PORT="${REMOTE_PORT:-22}"

# Validate the variables
if [[ -z "${USER}" ]]; then
    echo "Error: user is not defined."
    exit 1
fi

if [[ -z "${REMOTE_HOST}" ]]; then
    echo "Error: remote host is not defined."
    exit 1
fi

if [[ -z "${SOURCE_PORT}" ]]; then
    echo "Error: source port is not defined."
    exit 1
fi

if [[ -z "${TARGET_HOST}" ]]; then
    echo "Error: target host is not defined."
    exit 1
fi

if [[ -z "${TARGET_PORT}" ]]; then
    echo "Error: target port is not defined."
    exit 1
fi

if [[ -z "${CERTIFICATE_PATH}" ]]; then
    echo "Error: certificate path is not defined."
    exit 1
fi

# Function to check if a command is installed
check_command_installed() {
    local command_name="$1"
    if ! command -v "$command_name" &> /dev/null; then
        echo "Error: $command_name is not installed. Please install $command_name before running this script."
        exit 1
    fi
}

# Verify SSH, nslookup, and netcat (nc) are installed
check_command_installed "ssh"
check_command_installed "nslookup"
check_command_installed "nc"

# Function to check if the target host and port are accessible
check_target_accessibility() {
    nc -z -w 2 "${TARGET_HOST}" "${TARGET_PORT}" >/dev/null 2>&1
    return $?
}

# Check if the target host and port are accessible
if check_target_accessibility; then
    echo "Target host and port are accessible."
else
    echo "Error: Target host and/or port are not accessible."
    exit 1
fi

# Perform nslookup on the target host and iterate over the resolved addresses
resolved_addresses=$(nslookup "${REMOTE_HOST}" | awk '/^Address: / { print $2 }')
echo "Creating ssh tunnels"

# Dictionary to store tunnel PIDs and resolved addresses
declare -A tunnel_pids

# PID for keepalive process
keepalive_pid=""

# Function to cleanup tunnel processes
cleanup() {
    echo "Cleaning tunnel processes"
    for pid in "${!tunnel_pids[@]}"; do
        if [[ -d "/proc/$pid" ]]; then
            kill "$pid" &> /dev/null
            echo "Killed tunnel process with PID: $pid"
        fi
    done
    # Kill keepalive process if running
    if [[ -n "$keepalive_pid" ]] && kill -0 "$keepalive_pid" &> /dev/null; then
        kill "$keepalive_pid" &> /dev/null
        echo "Killed keepalive process with PID: $keepalive_pid"
    fi
}

# Function to send keepalive probes to TARGET_HOST:TARGET_PORT
start_keepalive() {
    echo "Starting keepalive process for ${TARGET_HOST}:${TARGET_PORT} (interval: ${KEEPALIVE_INTERVAL}s)"
    while true; do
        sleep "${KEEPALIVE_INTERVAL}"
        # Send a minimal probe to keep the connection alive
        echo -n "" | nc -w 2 "${TARGET_HOST}" "${TARGET_PORT}" >/dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "Keepalive probe to ${TARGET_HOST}:${TARGET_PORT} succeeded"
        else
            echo "Keepalive probe to ${TARGET_HOST}:${TARGET_PORT} failed"
        fi
    done &
    keepalive_pid=$!
    echo "Keepalive process started with PID: $keepalive_pid"
}

# Trap exit signal and perform cleanup
trap cleanup EXIT

# Function to create SSH tunnel
create_ssh_tunnel() {
    local resolved_address="$1"
    echo "Creating reverse tunnel for ${resolved_address}..."
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -i "${CERTIFICATE_PATH}/id_rsa" -i "${CERTIFICATE_PATH}/id_rsa.signed" -N -R "0.0.0.0:${SOURCE_PORT}:${TARGET_HOST}:${TARGET_PORT}" -p "${REMOTE_PORT}" "${USER}@${resolved_address}" &
    tunnel_pids[$!]=$resolved_address
}

# Iterate over resolved addresses and create SSH tunnels
for resolved_address in $resolved_addresses; do
    create_ssh_tunnel "$resolved_address"
done

echo "All tunnels created successfully"

# Start keepalive process for TARGET_HOST:TARGET_PORT
start_keepalive

# Continuously monitor the background tunnel processes
while true; do
     # Perform nslookup on the target host and iterate over the resolved addresses
    resolved_addresses=$(nslookup "${REMOTE_HOST}" | awk '/^Address: / { print $2 }')

    # Check if there are new IP addresses that don't exist in tunnel_pids dictionary
    for resolved_address in $resolved_addresses; do
        if [[ ! " ${tunnel_pids[@]} " =~ " ${resolved_address} " ]]; then
            create_ssh_tunnel "$resolved_address"
        fi
    done

    # Check if any tunnel processes have died
    dead_tunnels=0
    for pid in "${!tunnel_pids[@]}"; do
        if ! kill -0 "$pid" &> /dev/null; then
            ((dead_tunnels++))
            unset "tunnel_pids[$pid]"
        fi
    done

    if [[ $dead_tunnels -eq ${#tunnel_pids[@]} ]]; then
        echo "All tunnel processes have died. Exiting."
        exit 1
    fi

    for ((i=dead_tunnels; i>0; i--)); do
        resolved_address="${tunnel_pids[$pid]}"
        create_ssh_tunnel "$resolved_address"
    done

    sleep "${SLEEP_DURATION}"
done