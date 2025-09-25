# Flytube - Firefly Relay Backend

This repository provides a solution for creating a reverse SSH tunnel between a local service and the Firefly Relay frontend. The reverse SSH tunnel allows the local service to securely expose a local port to the Firefly Relay frontend, enabling communication between them.

## Background

A reverse SSH tunnel establishes a secure connection from a remote server to a local server, allowing traffic to be forwarded from the local server to the remote server. In the context of Firefly Relay, 
 this enables the local service to communicate with the Firefly Relay frontend by forwarding traffic through the established reverse SSH tunnel.

 ![image](https://github.com/gofireflyio/flytube/assets/31516429/f40336ea-9762-4b9c-bd0b-eddc399e7d3c)

 
## Installation

### Helm

1. Install Helm on your local machine.

2. Clone this repository:

```helm repo add flytube https://gofireflyio.github.io/firefly-private-connector```

```helm repo update```

3. Fill in the required values in `values.yaml` file:

```yaml

env:
    user: "<supplied username>"
    remoteHost: "firefly-relay.firefly.ai "
    remotePort: 22
    sourcePort: 8080
    targetHost: "<target host ip/>"
    targetPort: 80
    sleepDuration: 5

image:
  repository: flytube
  tag: 1.0.0

resources:
  limits:
    cpu: "1"
    memory: "512Mi"
  requests:
    cpu: "500m"
    memory: "256Mi"

```

4. Copy supplied certificates into the `certs` directory.

```kubectl create secret generic fpc-certificates --from-file=id_rsa=certs/id_rsa --from-file=id_rsa.pub=certs/id_rsa.pub --from-file=id_rsa.signed=certs/id_rsa.signed --namespace=firefly```

5. Deploy the application using Helm:

```helm install flytube flytube/fpc --values cmd/relay/values.yaml --namespace=firefly --create-namespace```


### Terraform

1. Install Terraform on your local machine.

2. Update the variables in `terraform.tfvars` file with the desired values.

3. Add a module call to the flytube terraform module.
```terraform
provider "aws" {
  region = var.aws_region
}

module "ec2_instance" {
  source = "github.com/gofireflyio/flytube//flytube-terraform?ref=v0.1.0"

  instance_ami         = "ami-12345678"
  instance_type        = "t2.micro"
  key_pair_name        = "my-keypair"
  security_group_id    = "sg-12345678"
  user                 = "myuser"
  remote_host          = "firefly-relay.firefly.ai"
  remote_port          = 22
  source_port          = 8080
  target_host          = "target-host"
  target_port          = 80
  certificate_path     = "secrets/ssh-certificate"
  certificate_pem      = "GIVEN_BY_FIREFLY"
  sleep_duration       = var.sleep_duration
  aws_region           = var.aws_region
}
```

4. Initialize the Terraform working directory:

```terraform init```

6. View the Terraform execution plan:

```terraform plan```

7. Provision the EC2 instance:

```terraform apply```

## Configuration

The configuration options for the application can be modified by updating the values in the `values.yaml` file for Docker Helm installation or the `terraform.tfvars` file for Terraform installation.

## License

This project is licensed under the [MIT License](LICENSE).
