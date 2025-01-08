#!/bin/bash

cd /

# Check if a service name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <service-name>"
    exit 1
fi

SERVICE_NAME=$1

# Retrieve the user associated with the systemd service
SERVICE_USER=$(systemctl show "$SERVICE_NAME" --property=User --value)

# Check if the user is retrieved successfully
if [ -z "$SERVICE_USER" ]; then
    echo "Failed to find a user for the service: $SERVICE_NAME"
    exit 1
fi

# Run a command inside the container using Podman
sudo -u "$SERVICE_USER" podman exec -i "$SERVICE_NAME" sh
