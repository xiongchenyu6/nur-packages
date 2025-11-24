# xiongchenyu6's NUR Packages

**A collection of unique Nix packages and NixOS modules not available in nixpkgs**

[![Build and populate cache](https://github.com/xiongchenyu6/nur-packages/workflows/Build%20and%20populate%20cache/badge.svg)](https://github.com/xiongchenyu6/nur-packages/actions)
[![Cachix Cache](https://img.shields.io/badge/cachix-xiongchenyu6-blue.svg)](https://xiongchenyu6.cachix.org)
[![NUR](https://img.shields.io/badge/NUR-xiongchenyu6-green.svg)](https://nur.nix-community.org/repos/xiongchenyu6/)

## 🌟 Why Use This Repository?

This NUR repository provides packages and modules that are **not available in nixpkgs**, including:

- **Enterprise Security Tools** - CrowdStrike Falcon sensor, security agents
- **Distributed Computing** - Hashtopolis (distributed hashcat), FitCrack
- **Blockchain Infrastructure** - BTTC, Java-TRON, Chainlink nodes
- **Developer Tools** - Specialized editors, SDK tools, database utilities
- **System Services** - Advanced monitoring, notification systems, deployment agents

## 📦 Unique Packages

### Security & Cracking Tools
- **`hashtopolis-server`** - Distributed hashcat task management server
- **`hashtopolis-agent`** - Agent for distributed password cracking with CUDA support
- **`fitcrack`** - BOINC-based distributed password cracking system
- **`falcon-sensor`** - CrowdStrike Falcon endpoint protection

### Developer Tools
- **`haystack-editor`** - IDE for large-scale code editing
- **`gotron-sdk`** - TRON blockchain SDK for Go
- **`helmify`** - Convert Kubernetes YAML to Helm charts
- **`korb`** - Kubernetes OpenAPI resource builder
- **`my2sql`** - MySQL binlog parser

### Enterprise Applications
- **`feishu-lark`** - Lark/Feishu collaboration platform
- **`sui`** - Sui blockchain tools

### System Utilities
- **`record_screen`** - Screen recording utility
- **`ldap-extra-schemas`** - Additional LDAP schemas
- **`ldap-passthrough-conf`** - LDAP passthrough configuration

## 🔧 Unique NixOS Modules

### Security Services
```nix
services.hashtopolis-server = {
  enable = true;
  # Distributed hashcat management with web interface
};

services.hashtopolis-agent = {
  enable = true;
  deviceTypes = [ "cpu" "gpu" ];  # CUDA/OpenCL support
  useNativeHashcat = true;
};

services.falcon-sensor = {
  enable = true;
  # CrowdStrike Falcon EDR integration
};
```

### Blockchain Nodes
```nix
services.bttc = {
  enable = true;
  # BitTorrent Chain node
};

services.java-tron = {
  enable = true;
  # TRON blockchain full node
};

services.chainlink = {
  enable = true;
  # Chainlink oracle node
};
```

### Monitoring & Notifications
```nix
services.ssh-gotify-notify = {
  enable = true;
  # SSH login notifications via Gotify
};

services.unit-status-telegram = {
  enable = true;
  # Systemd unit status alerts to Telegram
};

services.oci-arm-host-capacity = {
  enable = true;
  # Oracle Cloud ARM instance availability monitor
};
```

### Development Infrastructure
```nix
services.phabricator = {
  enable = true;
  # Complete Phabricator development platform
};

services.postgrest = {
  enable = true;
  # RESTful API for PostgreSQL
};

services.codedeploy-agent = {
  enable = true;
  # AWS CodeDeploy agent for NixOS
};
```

## 🚀 Installation

### Method 1: Using Flakes (Recommended)

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    xiongchenyu6.url = "github:xiongchenyu6/nur-packages";
  };

  outputs = { self, nixpkgs, xiongchenyu6, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        # Add modules
        xiongchenyu6.nixosModules.hashtopolis-server
        xiongchenyu6.nixosModules.hashtopolis-agent

        # Use packages
        ({ pkgs, ... }: {
          environment.systemPackages = [
            xiongchenyu6.packages.${pkgs.system}.haystack-editor
            xiongchenyu6.packages.${pkgs.system}.fitcrack
          ];
        })
      ];
    };
  };
}
```

### Method 2: Using NUR

```nix
{
  nixpkgs.config.packageOverrides = pkgs: {
    nur = import (builtins.fetchTarball "https://github.com/nix-community/NUR/archive/master.tar.gz") {
      inherit pkgs;
    };
  };
}
```

Then use packages:
```nix
environment.systemPackages = with pkgs.nur.repos.xiongchenyu6; [
  haystack-editor
  fitcrack
];
```

### Method 3: Direct Import

```nix
let
  xiongchenyu6 = import (builtins.fetchTarball {
    url = "https://github.com/xiongchenyu6/nur-packages/archive/master.tar.gz";
    # Optional: pin to specific commit
    # sha256 = "...";
  }) { inherit pkgs; };
in {
  environment.systemPackages = [
    xiongchenyu6.haystack-editor
  ];
}
```

## 📋 Complete Package List

### Packages (`pkgs/`)
- `emacs` - Custom Emacs configuration
- `falcon-sensor` - CrowdStrike Falcon sensor
- `feishu-lark` - Feishu/Lark collaboration platform
- `fitcrack` - Distributed password cracking (BOINC)
- `gotron-sdk` - TRON SDK for Go
- `hashtopolis-agent` - Hashtopolis cracking agent
- `hashtopolis-server` - Hashtopolis management server
- `haystack-editor` - Large-scale code editor
- `helmify` - Kubernetes to Helm converter
- `korb` - Kubernetes resource builder
- `ldap-extra-schemas` - Additional LDAP schemas
- `ldap-passthrough-conf` - LDAP passthrough configs
- `my2sql` - MySQL binlog parser
- `record_screen` - Screen recording tool
- `sui` - Sui blockchain tools

### Modules (`modules/`)
- `binbash` - Binary bash module
- `bttc` - BitTorrent Chain node
- `chainlink` - Chainlink oracle node
- `codedeploy-agent` - AWS CodeDeploy agent
- `falcon-sensor` - CrowdStrike Falcon service
- `hashtopolis-agent` - Distributed hashcat agent
- `hashtopolis-server` - Hashcat task server
- `java-tron` - TRON blockchain node
- `netbird` - NetBird VPN service
- `oci-arm-host-capacity` - OCI ARM monitor
- `phabricator` - Development platform
- `postgrest` - PostgreSQL REST API
- `ssh-gotify-notify` - SSH notification service
- `tat-agent` - TAT agent service
- `unit-status-telegram` - Telegram notifications

## 🛠 Development

### Prerequisites
```bash
# Development shell with tools
nix develop

# Available tools:
# - nixfmt-rfc-style (code formatter)
# - nixd (language server)
# - statix (static analyzer)
```

### Building Packages
```bash
# Build specific package
nix build .#hashtopolis-server

# Build all packages
nix build .#all-packages
```

### Testing Modules
```bash
# Test module in VM
nixos-rebuild build-vm --flake .#test-config
```

### Updating Dependencies
```bash
# Update all flake inputs
nix run .#update
```

## 🏗 Templates

This repository includes project templates for quick starts:

```bash
# List available templates
nix flake show github:xiongchenyu6/nur-packages

# Use a template
nix flake init -t github:xiongchenyu6/nur-packages#python
nix flake init -t github:xiongchenyu6/nur-packages#rust
nix flake init -t github:xiongchenyu6/nur-packages#cuda
```

Available templates:
- `bun` - Bun JavaScript runtime
- `c` - C/C++ development
- `cuda` - CUDA GPU programming
- `go` - Go development
- `java` - Java/JVM development
- `nixos` - NixOS configuration
- `nodejs` - Node.js projects
- `python` - Python development
- `rust` - Rust development
- `shell` - Shell scripting
- `terraform` - Infrastructure as Code

## 📊 Supported Platforms

- ✅ `x86_64-linux`
- ✅ `aarch64-linux`
- ✅ `aarch64-darwin`
- ✅ `x86_64-darwin`

## 🤝 Contributing

Contributions are welcome! If you have a package or module that's not in nixpkgs:

1. Fork this repository
2. Add your package/module following the existing structure
3. Test your changes
4. Submit a pull request

## 📄 License

This repository follows the MIT license for custom code. Individual packages may have their own licenses.

## 🔗 Links

- [NUR Repository](https://nur.nix-community.org/repos/xiongchenyu6/)
- [Cachix Binary Cache](https://xiongchenyu6.cachix.org)
- [GitHub Issues](https://github.com/xiongchenyu6/nur-packages/issues)

## 💡 Examples

### Setting up Hashtopolis for Distributed Password Cracking
```nix
{
  services.hashtopolis-server = {
    enable = true;
    database = {
      host = "localhost";
      name = "hashtopolis";
      user = "hashtopolis";
    };
  };

  services.hashtopolis-agent = {
    enable = true;
    serverUrl = "http://localhost:8080/api/server.php";
    deviceTypes = [ "cpu" "gpu" ];
    useNativeHashcat = true;
    hashcatPackage = pkgs.hashcat;
  };
}
```

### Running a TRON Full Node
```nix
{
  services.java-tron = {
    enable = true;
    network = "mainnet";
    httpPort = 8090;
    rpcPort = 50051;
  };
}
```

## 📧 Contact

For questions or support, please [open an issue](https://github.com/xiongchenyu6/nur-packages/issues) on GitHub.

---

**Note**: This repository contains packages not available in nixpkgs. For standard packages, please use nixpkgs directly.