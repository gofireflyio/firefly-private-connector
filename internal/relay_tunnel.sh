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

while true
do
    if ssh -i "${CERTIFICATE_PATH}" -N -R "0.0.0.0:${SOURCE_PORT}:${TARGET_HOST}:${TARGET_PORT}" -p "${REMOTE_PORT}" "${USER}@${REMOTE_HOST}"; then
        echo "Reverse tunnel created successfully."
    else
        echo "Failed to create reverse tunnel. Retrying in ${SLEEP_DURATION} seconds..."
        sleep "${SLEEP_DURATION}"
    fi
done
