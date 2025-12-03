# Fleet Service Module

This NixOS module provides a systemd service for [Fleet](https://fleet.rancher.io/), a GitOps operator for Kubernetes.

## Usage

Add to your NixOS configuration:

```nix
{
  imports = [ ./path/to/nur-packages/modules ];
  
  services.fleet = {
    enable = true;
    # Optional configuration
    namespace = "cattle-fleet-system";  # default
    kubeconfig = "/path/to/kubeconfig";
    enableLeaderElection = true;        # default
    debug = false;                      # default
    debugLevel = 0;                     # default
    disableMetrics = false;             # default
    metricsBindAddress = ":8080";       # default
    healthProbeBindAddress = ":8081";   # default
    shardId = null;                     # default
    
    # Configure reconciler workers
    reconcilerWorkers = {
      bundle = 50;
      bundleDeployment = 50;
      cluster = 50;
      clusterGroup = 50;
      imageScan = 50;
      schedule = 50;
      content = 50;
    };
    
    # Extra environment variables
    extraEnv = {
      OCI_STORAGE = "false";
      EXPERIMENTAL_COPY_RESOURCES_DOWNSTREAM = "false";
    };
    
    extraArgs = [ "--additional-flag" ];
  };
}
```

## Configuration Options

### Basic Options
- `enable`: Enable the Fleet service (default: false)
- `package`: Fleet package to use (default: pkgs.fleet)
- `namespace`: Kubernetes namespace to watch for Fleet resources (default: "cattle-fleet-system")
- `kubeconfig`: Path to kubeconfig file (default: null, uses KUBECONFIG env or default)

### Controller Options
- `disableMetrics`: Disable metrics endpoint (default: false)
- `shardId`: Only manage resources labeled with a specific shard ID (default: null)
- `enableLeaderElection`: Enable leader election for controller manager (default: true)

### Debug Options
- `debug`: Enable debug logging (default: false)
- `debugLevel`: Debug level 0-9 (default: 0)

### Networking Options
- `metricsBindAddress`: Bind address for metrics endpoint (default: ":8080")
- `healthProbeBindAddress`: Bind address for health probe endpoint (default: ":8081")

### Reconciler Workers
Configure the number of workers for each reconciler type:
- `reconcilerWorkers.bundle`: Bundle reconciler workers
- `reconcilerWorkers.bundleDeployment`: Bundle deployment reconciler workers  
- `reconcilerWorkers.cluster`: Cluster reconciler workers
- `reconcilerWorkers.clusterGroup`: Cluster group reconciler workers
- `reconcilerWorkers.imageScan`: Image scan reconciler workers
- `reconcilerWorkers.schedule`: Schedule reconciler workers
- `reconcilerWorkers.content`: Content reconciler workers

### Advanced Options
- `extraEnv`: Extra environment variables (default: {})
- `extraArgs`: Extra command-line arguments (default: [])

## Fleet Controller Command Structure

The Fleet controller binary (`fleetcontroller`) is a Kubernetes controller that doesn't require a separate configuration file. Instead, it uses:

1. **Command-line arguments** for basic configuration
2. **Environment variables** for advanced configuration
3. **Kubernetes RBAC** and **kubeconfig** for cluster access

The controller automatically:
- Discovers and manages Fleet resources in the specified namespace
- Uses the Kubernetes API for all configuration and state management
- Provides metrics on `:8080` and health checks on `:8081`
- Enables leader election by default for high availability

## Prerequisites

- The `fleet` package must be available in nixpkgs or provided via an overlay
- Kubernetes cluster access configured via kubeconfig or in-cluster configuration
- Appropriate RBAC permissions for Fleet controller
- Fleet CRDs installed in the cluster

## Security

The service runs with:
- Dedicated `fleet` user and group
- Private tmp directory
- Protected home and system directories
- No new privileges
- Write access only to `/var/lib/fleet`

## Installation

Fleet requires CRDs and proper RBAC setup. This module only provides the controller service. 
You'll need to install Fleet CRDs and configure RBAC separately:

```bash
# Install Fleet CRDs
kubectl apply -f https://github.com/rancher/fleet/releases/latest/download/fleet-crd.yaml

# Apply RBAC (depends on your setup)
kubectl apply -f https://github.com/rancher/fleet/releases/latest/download/fleet.yaml
```