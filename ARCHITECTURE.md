# Firefly Private Connector - Architecture

This document explains how the Firefly Private Connector (Flytube) establishes secure, outbound-only connectivity between customer environments and the Firefly platform.

---

## Physical Network Connection (Outbound-Only)

```
┌──────────────────────────┐                  ┌──────────────────────────┐
│   Customer Network       │                  │  Firefly Infrastructure  │
│                          │                  │                          │
│    ┌──────────────┐      │                  │    ┌──────────────┐      │
│    │   Flytube    │──────┼──SSH Port 22────►│    │    Relay     │      │
│    │  Container   │      │   (OUTBOUND)     │    │    Server    │      │
│    └──────────────┘      │                  │    └──────────────┘      │
│                          │                  │                          │
│  Private Resources       │                  │  Firefly Platform        │
│  (VCS, TFE, K8s)         │                  │  <TARGET_HOST>           │
│                          │                  │  (proxy service)         │
└──────────────────────────┘                  └──────────────────────────┘
     ONE OUTBOUND SSH CONNECTION
     All traffic flows through it
```

**Key Point:** Only ONE outbound SSH connection is established from the customer network to `firefly-relay.firefly.ai:22`. No inbound firewall rules are required.

---

## Logical Data Flow (Through the Single Tunnel)

### Step 1: Firefly Platform Initiates Request

```
┌────────────────────────────────────────────────────┐
│  Firefly Infrastructure                            │
│                                                    │
│   Firefly Platform ──► Relay:<SOURCE_PORT>         │
│                             │                      │
└─────────────────────────────┼──────────────────────┘
                              ↓
                      (through tunnel)
```

### Step 2: Request Flows Through Tunnel to Flytube

```
┌────────────────────────────────────────────────────┐
│  Customer Network                                  │
│                                                    │
│   Flytube receives request ◄── (via tunnel)        │
│        │                                           │
└────────┼───────────────────────────────────────────┘
         ↓
   (Flytube connects to TARGET_HOST)
```

### Step 3: Flytube Connects to TARGET_HOST (Back Through Tunnel)

```
┌────────────────────────────────────────────────────┐
│  Customer Network                                  │
│                                                    │
│   Flytube ──► <TARGET_HOST>:<TARGET_PORT>          │
│              (routes back through same tunnel)     │
└────────────────────────────────────────────────────┘
                              ↓
                     (back through tunnel)
```

### Step 4: Reaches Firefly Proxy Service

```
┌────────────────────────────────────────────────────┐
│  Firefly Infrastructure                            │
│                                                    │
│   <TARGET_HOST> (Firefly proxy service)            │
│   receives request from tunnel                     │
│        │                                           │
└────────┼───────────────────────────────────────────┘
         ↓
   (proxy routes back through tunnel AGAIN)
```

### Step 5: Proxy Routes Back Through Tunnel to Customer Resources

```
┌────────────────────────────────────────────────────┐
│  Customer Network                                  │
│                                                    │
│   Customer's Private Resources                     │
│   (VCS, TFE, K8s, etc.)                            │
│   ◄── receives request via tunnel                  │
│        │                                           │
└────────┼───────────────────────────────────────────┘
         ↓
```

### Step 6: Response Flows Back Same Path

```
Private Resource → (tunnel) → Firefly Proxy → 
(tunnel) → Flytube → (tunnel) → Relay → Firefly Platform
```

---

## Complete Round-Trip Visualization

```
┌───────────────────────┐    SSH Tunnel (Port 22)      ┌───────────────────────┐
│  Customer Network     │◄════════════════════════════►│ Firefly Infrastructure│
│                       │   (ONE outbound connection)  │                       │
│                       │                              │                       │
│  ┌─────────────┐      │                              │   ┌─────────────┐     │
│  │  Private    │◄─────┼──────(6)───────────────(5)───┤───│  Firefly    │     │
│  │  Resources  │      │                              │   │   Proxy     │     │
│  │ (VCS/TFE/   │      │                              │   │<TARGET_HOST>│     │
│  │  K8s, etc.) │      │                              │   └──────┬──────┘     │
│  └─────────────┘      │                              │          │            │
│         ▲             │                              │         (4)           │
│         │             │                              │          │            │
│        (6)            │                              │          ▼            │
│         │             │                              │   ┌─────────────┐     │
│  ┌──────┴──────┐      │                              │   │    Relay    │     │
│  │   Flytube   │──────┼──────(3)─────────────────────┤──►│<SOURCE_PORT>│     │
│  │  Container  │◄─────┼──────(2)─────────────────────┤───│             │     │
│  └─────────────┘      │                              │   └──────▲──────┘     │
│                       │                              │          │            │
└───────────────────────┘                              │         (1)           │
   ONE OUTBOUND SSH                                    │          │            │
   All steps use same tunnel                           │   ┌──────┴──────┐     │
                                                       │   │  Firefly    │     │
                                                       │   │  Platform   │     │
                                                       │   └─────────────┘     │
                                                       └───────────────────────┘
```

**Data Flow:**
1. Firefly Platform initiates request → Relay
2. Relay forwards through tunnel → Flytube
3. Flytube connects to TARGET_HOST (back through tunnel) → Firefly Proxy
4. Firefly Proxy processes request
5. Proxy routes back through tunnel → Customer's Private Resources
6. Response returns through same path

---

## Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `SOURCE_PORT` | Unique port on Firefly relay server | `456789` |
| `TARGET_HOST` | Firefly proxy hostname | `customer.relay.firefly.ai` |
| `TARGET_PORT` | Port on Firefly proxy (typically HTTPS) | `443` |

All parameters are provided by the Firefly team during onboarding.

---

## Key Architecture Principles

### Outbound-Only Connectivity
- ✅ Customer opens **ONE** outbound SSH connection to `firefly-relay.firefly.ai:22`
- ✅ **NO** inbound firewall rules required in customer network
- ✅ **NO** inbound connections to customer infrastructure
- ✅ All connections initiated from customer environment

### Bidirectional Data Routing
- SSH tunnel provides bidirectional routing capability within the single outbound connection
- Data traverses the tunnel multiple times in both directions
- "Hairpin" routing: requests go out and come back through the same tunnel
- Customer resources never directly exposed to the internet

### Security Model
- **Encryption**: All traffic encrypted via SSH (AES-256)
- **Authentication**: Certificate-based SSH authentication (no passwords)
- **Isolation**: No direct internet exposure of private resources
- **Compliance**: Meets "no-ingress" security requirements

---

## How It Works: The Hairpin Pattern

The connector uses a "hairpin" routing pattern where:

1. **Firefly initiates** all requests from its platform
2. **Requests flow through** the tunnel to reach Flytube in customer network
3. **Flytube forwards** requests back through the same tunnel to Firefly's proxy service
4. **Firefly proxy** routes the request back through the tunnel again to reach customer's actual private resources
5. **Responses return** along the same path

This pattern allows:
- Outbound-only connectivity from customer perspective
- Firefly to access private resources without direct network access
- No VPN, PrivateLink, or other private network connections required
- Complete isolation of customer resources from the internet

---

## Network Requirements

**From Customer Network:**
- Outbound SSH/22 access to `firefly-relay.firefly.ai`
- DNS resolution capability for `firefly-relay.firefly.ai`
- Outbound HTTPS/443 access to `TARGET_HOST` (provided by Firefly)

**Firewall Rules:**
```bash
# Allow outbound SSH to Firefly relay
ALLOW tcp from <connector-ip> to firefly-relay.firefly.ai port 22

# Allow outbound HTTPS to Firefly target host
ALLOW tcp from <connector-ip> to <TARGET_HOST> port 443

# Allow DNS queries
ALLOW udp from <connector-ip> to <dns-server> port 53
```

**No Inbound Rules Required** ✅

---

## Integration Flow

Once the connector is deployed and the tunnel is established:

1. Configure private integrations in Firefly platform UI
2. Firefly automatically routes requests through the relay
3. Private resources (VCS, TFE, K8s, etc.) are accessed via the tunnel
4. No changes required to private resources themselves
5. Resources remain isolated from internet

**Supported Private Integrations:**
- Version Control Systems (GitLab, GitHub Enterprise, Bitbucket, Azure DevOps)
- Terraform Enterprise / Terraform Cloud Agents
- Kubernetes Clusters (EKS, GKE, AKS, on-premises)
- State Backends (S3, Consul, etcd)
- Configuration Management (Ansible Tower, Chef, Puppet)
- Cloud Provider Private Endpoints

---

## Summary

The Firefly Private Connector achieves secure access to customer private resources through:

- **Single outbound SSH connection** (no inbound firewall changes)
- **Bidirectional tunnel routing** (hairpin pattern through Firefly proxy)
- **Certificate-based authentication** (no passwords)
- **End-to-end encryption** (SSH + HTTPS)
- **Zero internet exposure** (resources remain private)

This architecture provides enterprise-grade security while maintaining operational simplicity and compliance with strict "no-ingress" policies.

