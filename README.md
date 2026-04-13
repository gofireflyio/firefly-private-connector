# Firefly Private Connector - Flytube

The Firefly Private Connector establishes a secure, outbound-only reverse SSH tunnel from your environment to the Firefly platform, enabling Firefly to access private resources without requiring inbound firewall rules or exposing internal services to the internet.

## Overview

This connector enables secure communication between the Firefly platform and resources in your private network. The connector initiates an outbound SSH connection from your infrastructure to Firefly's relay infrastructure (`firefly-relay.firefly.ai`), creating a reverse tunnel that Firefly uses to route traffic to your internal services.

### How It Works

1. **Outbound Connection**: The connector establishes an SSH connection from your network to `firefly-relay.firefly.ai:22`
2. **Certificate Authentication**: Uses SSH certificate-based authentication with certificates provided by Firefly
3. **Reverse Tunnel**: Creates a reverse tunnel binding a remote port on Firefly's relay server
4. **Private Integration Access**: After the relay is established, all private integrations such as on-premises VCS tools, private Terraform Enterprise instances, internal Kubernetes clusters, or other tools that store infrastructure state are accessed through this tunnel, allowing the Firefly platform to connect securely to your environment

### Technical Architecture

📖 **For a detailed explanation of the architecture including the complete data flow, hairpin routing pattern, and step-by-step request/response cycle, see [ARCHITECTURE.md](ARCHITECTURE.md).**

**Connection Flow:**
```
Your Network                                Firefly Infrastructure
┌──────────────────────────┐               ┌──────────────────────────┐
│                          │               │                          │
│  ┌──────────────────┐    │               │  ┌──────────────────┐    │
│  │ Private Connector│────┼───SSH Port 22─┼─→│  Relay Server    │    │
│  │   (Container)    │    │   Outbound    │  │                  │    │
│  └──────────────────┘    │               │  └──────────────────┘    │
│                          │               │          ↑               │
│  Private Resources       │               │  Firefly Platform        │
│  (VCS, TFE, K8s, etc.)   │               │  connects via relay      │
│                          │               │                          │
└──────────────────────────┘               └──────────────────────────┘
     Outbound Only                              
     No ingress needed                          Reverse SSH Tunnel
```

**SSH Tunnel Command:**
```bash
ssh -N -R 0.0.0.0:<SOURCE_PORT>:<TARGET_HOST>:<TARGET_PORT> \
    -p 22 \
    -i /certs/id_rsa \
    -i /certs/id_rsa.signed \
    <USER>@firefly-relay.firefly.ai
```

**Security Characteristics:**
- **Outbound-only**: No inbound firewall rules required in your network
- **Certificate authentication**: Uses SSH certificates (not passwords) for authentication
- **Encrypted transport**: All traffic encrypted via SSH protocol (AES-256)
- **Ephemeral connections**: Automatically reconnects if connection drops
- **DNS-aware**: Monitors relay DNS for IP changes and maintains tunnels to all resolved addresses
- **Process monitoring**: Detects dead tunnels and recreates them automatically

**Network Requirements:**
- Outbound HTTPS/443 access to target host (provided by Firefly team)
- Outbound SSH/22 access to `firefly-relay.firefly.ai` (may require firewall allowlist)
- DNS resolution capability for `firefly-relay.firefly.ai`

## Prerequisites

- Kubernetes cluster (for Helm deployment), AWS account (for Terraform deployment), or any Linux virtual machine or bare-metal server (for Docker or systemd deployment)
- SSH certificates provided by the Firefly team:
  - `id_rsa` - Private SSH key
  - `id_rsa.pub` - Public SSH key
  - `id_rsa.signed` - Certificate-signed public key
- Configuration values provided by the Firefly team:
  - `user` - Unique identifier for your connector instance
  - `sourcePort` - Port on Firefly relay that will forward to your target
  - `targetHost` - Target hostname provided by Firefly for tunnel endpoint

## Installation

### Helm (Kubernetes)

**1. Add the Helm repository:**
```bash
helm repo add flytube https://gofireflyio.github.io/firefly-private-connector
helm repo update
```

**2. Create a Kubernetes secret with your SSH certificates:**
```bash
kubectl create secret generic fpc-certificates \
  --from-file=id_rsa=certs/id_rsa \
  --from-file=id_rsa.pub=certs/id_rsa.pub \
  --from-file=id_rsa.signed=certs/id_rsa.signed \
  --namespace=firefly
```

**3. Create a `values.yaml` file with your configuration:**
```yaml
env:
  user: "< SUPPLIED BY FIREFLY TEAM >"
  remoteHost: "firefly-relay.firefly.ai"
  targetHost: "< SUPPLIED BY FIREFLY TEAM >"
  remotePort: "22"  # Default chart value
  sourcePort: "< SUPPLIED BY FIREFLY TEAM >"
  targetPort: "443"
  sleepDuration: 5

image:
  repository: infralightio/flytube
  tag: latest
  pullPolicy: Always

resources:
  limits:
    memory: "512Mi"
  requests:
    cpu: "200m"
    memory: "256Mi"
```

**4. Deploy the connector:**
```bash
helm install flytube flytube/fpc \
  --values values.yaml \
  --namespace=firefly \
  --create-namespace
```

**5. Verify deployment:**
```bash
kubectl get pods -n firefly
kubectl logs -n firefly -l app.kubernetes.io/name=fpc
```

### Terraform (AWS EC2)

**1. Create a `terraform.tfvars` file:**
```hcl
aws_region        = "us-east-1"
instance_ami      = "ami-12345678"  # Amazon Linux 2 AMI for your region
instance_type     = "t3.micro"
key_pair_name     = "your-ec2-keypair"
security_group_id = "sg-xxxx"  # Security group allowing outbound SSH

user              = "< SUPPLIED BY FIREFLY TEAM >"
remote_host       = "firefly-relay.firefly.ai"
remote_port       = 22
source_port       = 8080  # < SUPPLIED BY FIREFLY TEAM >
target_host       = "internal-service.local"  # < SUPPLIED BY FIREFLY TEAM >
target_port       = 443
certificate_pem   = "< SUPPLIED BY FIREFLY TEAM >"
sleep_duration    = 5
```

**2. Initialize Terraform:**
```bash
terraform init
```

**3. Review the execution plan:**
```bash
terraform plan
```

**4. Deploy the connector:**
```bash
terraform apply
```

### Docker on a Virtual Machine (Any Platform)

This method works on any Linux virtual machine or bare-metal server, including VMware vSphere/ESXi, Azure VMs, GCP Compute Engine, Oracle Cloud, or on-premises infrastructure.

**Requirements:**
- A Linux VM (Ubuntu, RHEL, CentOS, Amazon Linux, Debian, etc.)
- Docker installed (or `openssh-client`, `nslookup`, and `nc` for systemd-only deployment)
- Outbound access to `firefly-relay.firefly.ai` on port 22 and to the target host on port 443
- SSH certificates provided by the Firefly team

**1. Copy the SSH certificates to the VM:**
```bash
mkdir -p /opt/firefly/certs
# Copy id_rsa, id_rsa.pub, and id_rsa.signed to /opt/firefly/certs/
chmod 600 /opt/firefly/certs/*
```

**2. Run the connector using Docker:**
```bash
docker run -d \
  --name firefly-connector \
  --restart always \
  -e USER="< SUPPLIED BY FIREFLY TEAM >" \
  -e REMOTE_HOST="firefly-relay.firefly.ai" \
  -e SOURCE_PORT="< SUPPLIED BY FIREFLY TEAM >" \
  -e TARGET_HOST="< SUPPLIED BY FIREFLY TEAM >" \
  -e TARGET_PORT="443" \
  -e REMOTE_PORT="22" \
  -e SLEEP_DURATION="5" \
  -v /opt/firefly/certs:/certs:ro \
  infralightio/flytube:latest
```

**3. Verify the connector is running:**
```bash
docker logs -f firefly-connector
```

Look for `All tunnels created successfully` in the output.

#### Systemd Deployment (Without Docker)

If Docker is not available, you can run the connector directly using systemd.

**1. Install dependencies:**

*Debian/Ubuntu:*
```bash
apt-get update && apt-get install -y openssh-client dnsutils netcat-openbsd
```

*RHEL/CentOS/Amazon Linux:*
```bash
yum install -y openssh-clients bind-utils nmap-ncat
```

**2. Copy the tunnel script and certificates:**
```bash
cp internal/relay_tunnel.sh /usr/local/bin/relay_tunnel.sh
chmod +x /usr/local/bin/relay_tunnel.sh

mkdir -p /opt/firefly/certs
# Copy id_rsa, id_rsa.pub, and id_rsa.signed to /opt/firefly/certs/
chmod 600 /opt/firefly/certs/*
```

**3. Create the systemd service:**
```bash
cat > /etc/systemd/system/firefly-relay.service << 'EOF'
[Unit]
Description=Firefly Relay
After=network.target

[Service]
ExecStart=/usr/local/bin/relay_tunnel.sh
Environment=USER=< SUPPLIED BY FIREFLY TEAM >
Environment=REMOTE_HOST=firefly-relay.firefly.ai
Environment=SOURCE_PORT=< SUPPLIED BY FIREFLY TEAM >
Environment=TARGET_HOST=< SUPPLIED BY FIREFLY TEAM >
Environment=TARGET_PORT=443
Environment=REMOTE_PORT=22
Environment=CERTIFICATE_PATH=/opt/firefly/certs
Environment=SLEEP_DURATION=5
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
```

**4. Enable and start the service:**
```bash
systemctl daemon-reload
systemctl enable firefly-relay
systemctl start firefly-relay
```

**5. Verify:**
```bash
systemctl status firefly-relay
journalctl -u firefly-relay -f
```

## Configuration Parameters

| Parameter | Description | Example | Provided By |
|-----------|-------------|---------|-------------|
| `user` | Unique identifier for connector instance | `customer-acme` | Firefly Team |
| `remoteHost` | Firefly relay server hostname | `firefly-relay.firefly.ai` | Default |
| `remotePort` | SSH port on relay server | `22` | Default |
| `sourcePort` | Port on relay that forwards to target | `456789` | Firefly Team |
| `targetHost` | Target hostname/IP provided by Firefly for outbound connection | `acme.relay.firefly.ai` | Firefly Team |
| `targetPort` | Port of target service | `443` | Default |
| `sleepDuration` | Seconds between tunnel health checks | `5` | Default |

## Post-Installation: Enabling Private Integrations

After the relay is established, configure private integrations in the Firefly platform. The relay enables Firefly to securely access:

- **Version Control Systems**: GitLab, GitHub Enterprise, Bitbucket Server, Azure DevOps Server
- **Terraform Enterprise**: Private Terraform Enterprise or Terraform Cloud Agents
- **Kubernetes Clusters**: Private EKS, GKE, AKS, or on-premises Kubernetes clusters
- **State Backends**: Private S3-compatible storage, Consul, etcd
- **Cloud Provider APIs**: Private endpoints for AWS, Azure, GCP in isolated networks
- **Configuration Management**: Ansible Tower, Chef Server, Puppet Enterprise

All traffic from Firefly to these services routes through the established tunnel. Configure each integration in the Firefly platform UI using internal hostnames or IP addresses that are routable from the connector's deployment location.

## Security Considerations

**Authentication:**
- Certificate-based SSH authentication (no passwords)
- Certificates should be rotated according to your security policy
- Private keys are stored as Kubernetes secrets, AWS EC2 user data (encrypted at rest), or local files with restricted permissions (0600) on VMs

**Network Isolation:**
- Connector only requires outbound network access
- No inbound ports need to be opened in your firewall
- Target services remain unexposed to the internet

**Least Privilege:**
- Connector should only have network access to services Firefly needs
- Consider deploying in a dedicated network segment with restricted routing
- Use security groups/network policies to limit connector's network scope

**Monitoring:**
- Monitor connector logs for connection failures or anomalies
- Set up alerts for prolonged disconnections
- Review SSH certificate expiration dates

## Troubleshooting

**Connector fails to start:**
- Verify all required environment variables are set
- Confirm SSH certificates are correctly mounted and have proper permissions (0600)
- Check DNS resolution for `firefly-relay.firefly.ai` and `targetHost`

**Target host unreachable:**
- Verify `targetHost` is reachable from connector's network location
- Confirm `targetPort` is accessible using `nc -zv <targetHost> <targetPort>`
- Check network policies/security groups allow connector → target communication

**Tunnel disconnects frequently:**
- Review connector logs for specific SSH errors
- Verify network stability and firewall keep-alive settings
- Confirm `firefly-relay.firefly.ai` is not blocked by network policies

**Unable to access services through Firefly:**
- Verify connector is running: `kubectl get pods -n firefly` (Helm), check EC2 instance state (Terraform), `docker ps` or `systemctl status firefly-relay` (VM)
- Confirm tunnel is established: check connector logs for "All tunnels created successfully"
- Verify target service is running and accessible from connector's location

## Support

For assistance with the Firefly Private Connector:
- Contact Firefly support for certificate issues or configuration questions
- Review connector logs for detailed error messages
- Provide Firefly team with connector version and relevant log excerpts

## License

This project is licensed under the [MIT License](LICENSE).
