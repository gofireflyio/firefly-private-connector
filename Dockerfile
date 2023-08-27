# Use a lightweight base image
FROM alpine:3.18.0

# Install SSH and necessary tools
RUN apk update && \
    apk add --no-cache openssh-client && \
    apk add --no-cache bash

# Copy the relay_tunnel.sh script to the container
COPY internal/relay_tunnel.sh /usr/local/bin/relay_tunnel.sh

# Set execute permissions on the script
RUN chmod +x /usr/local/bin/relay_tunnel.sh

# Set the script as the entrypoint
ENTRYPOINT ["bash", "/usr/local/bin/relay_tunnel.sh"]
