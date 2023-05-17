provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "ec2_instance" {
  ami           = var.instance_ami
  instance_type = var.instance_type

  key_name               = var.key_pair_name
  vpc_security_group_ids = [var.security_group_id]

  user_data = <<-EOF
    #!/bin/bash

    # Get the user, remote host, remote port, source port, target host, target port, and certificate path from instance metadata
    USER="${var.user}"
    REMOTE_HOST="${var.remote_host}"
    REMOTE_PORT="${var.remote_port}"
    SOURCE_PORT="${var.source_port}"
    TARGET_HOST="${var.target_host}"
    TARGET_PORT="${var.target_port}"
    CERTIFICATE_PATH="${var.certificate_path}"
    SLEEP_DURATION="${var.sleep_duration}"

    # Install SSH
    yum install -y openssh-server

    # Write the certificate PEM to a file
    echo "${var.certificate_pem}" > /home/ec2-user/certificate.pem

    # Make the script executable
    chmod +x /home/ec2-user/certificate.pem

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

    # Start the script
    while true; do
      if ssh -i /home/ec2-user/certificate.pem -N -R ${SOURCE_PORT}:${TARGET_HOST}:${TARGET_PORT} -p ${REMOTE_PORT} ${USER}@${REMOTE_HOST}; then
        echo "Reverse tunnel created successfully."
      else
        echo "Failed to create reverse tunnel. Retrying in ${SLEEP_DURATION} seconds..."
        sleep ${SLEEP_DURATION}
      fi
    done
    EOF

  tags = merge(var.tags, {
    Name = "Firefly-Relay-Backend"
    AppVersion = var.app_version
    ModuleVersion = var.module_version
  })
}
