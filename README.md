# VS Code Offline Installer

This set of scripts helps you to install VS Code in an air-gapped offline environment, where you want to connect to remote SSH targets.

It also makes use of your company's HTTP proxy (currently mandatory arguments) and handles McAfee's Web Gateway.

## Installation

- Create or look up the credentials of a proxy service user
- On your internet-connected device:
  - Copy `load_env.ps1.example` to `load_env.ps1` and fill in your proxy information
  - Copy `extensions.json.example` to `extensions.json.example` and rename `target1` to a hostname where you want to use VS Code Remote SSH later.
    You can add as many (remote SSH target) hosts as you like; just make sure that the entries can be resolved using DNS.
  - Run `download_latest.ps1`
- Copy the resulting `.zip` file onto your air-gapped computer
- On the air-gapped computer/jumphost:
  - Run `00_install_jumphost_vscode.ps1`
  - Run `01_install_jumphost_extensions.ps1`
  - For each host in `extensions.json`:
    - Run `02_install_remote_vscode_server.ps1 <hostname/FQDN>`
    - Run `03_install_remote_extensions.ps1 <hostname/FQDN>`
