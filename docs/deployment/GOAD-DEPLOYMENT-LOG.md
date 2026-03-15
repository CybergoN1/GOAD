# GOAD Full Lab on Proxmox VE -- Deployment Guide

> **Date:** 2026-03-13
> **Status:** Phase 6 complete. GOAD fully deployed and verified on local-lvm.
> **Reference plan:** `GOAD-PVE-ACTION-PLAN.md`

This document records every step taken to deploy the GOAD (Game of Active Directory) Full lab on a Proxmox VE cluster. It is written as a reproducible deployment guide -- a new operator can follow it from start to finish.

---

## Table of Contents

- [Environment Overview](#environment-overview)
- [Prerequisites](#prerequisites)
- [Phase 0: SSH Access Setup](#phase-0-ssh-access-setup)
- [Phase 1: PVE Node Configuration](#phase-1-pve-node-configuration)
- [Phase 2: Upload ISOs to PVE](#phase-2-upload-isos-to-pve)
- [Phase 3: Packer Template Preparation](#phase-3-packer-template-preparation)
- [Phase 4: Configure GOAD](#phase-4-configure-goad)
- [Phase 5: Deploy GOAD](#phase-5-deploy-goad)
- [Phase 6: Post-Install Verification](#phase-6-post-install-verification)
- [Backups to NAS](#backups-to-nas)
- [Changes from Plan](#changes-from-plan)
- [Reliability Measures for Long-Running Installs](#reliability-measures-for-long-running-installs)
- [Phase 7: Exchange Extension](#phase-7-exchange-extension)
- [Troubleshooting Quick Reference](#troubleshooting-quick-reference)

---

## Environment Overview

| Component | Detail |
|-----------|--------|
| PVE cluster nodes | pve, pve2, pve3 |
| Target node | **pve2** -- 192.168.3.213, 20 cores, 32 GB RAM, PVE kernel 6.17.2-1-pve |
| Provisioning VM | **MrBot** -- VM 110, Ubuntu 24.04, 4 cores, 4 GB RAM, on pve2 at 192.168.3.106, user `admin1` |
| NAS | 192.168.3.253, SMB share `folder216`, user `MrShare` |
| Local workstation | macOS (used for SSH orchestration) |
| GOAD variant | GOAD Full (5 Windows VMs, 3 AD domains, 2 forests) |

### GOAD Resource Requirements

| Resource | Available on pve2 | GOAD Requires | Remaining After |
|----------|-------------------|---------------|-----------------|
| CPU cores | 20 (12 free) | 10 | 2 free |
| RAM | 32 GB (22 GB free) | ~20.2 GB | ~1.8 GB |
| Disk | ~816 GB free | ~200 GB | ~616 GB |

> **Warning:** RAM is tight. Consider stopping non-essential VMs when running the lab.

---

## Prerequisites

### Software Versions Used

| Software | Version | Location |
|----------|---------|----------|
| Packer | 1.15.0 | MrBot (apt, HashiCorp repo) |
| Terraform | 1.14.7 | MrBot (apt, HashiCorp repo) |
| Python | 3.12 | MrBot (system) |
| ansible-core | 2.18.0 | MrBot (pip, in venv) |
| Proxmox VE | kernel 6.17.2-1-pve | pve2 |
| Packer proxmox plugin | 1.2.3 | MrBot (packer init) |

### Ansible Galaxy Collections

These are installed on MrBot (system-wide or in the user context):

- `ansible.windows`
- `community.windows`
- `chocolatey.chocolatey`
- `ansible.posix`
- `scicore.guacamole`
- `community.mysql`
- `community.crypto`
- `community.general`

---

## Phase 0: SSH Access Setup

This phase establishes SSH connectivity from the local Mac workstation to both PVE and MrBot, and later from MrBot to PVE.

### 0.1 -- Generate SSH Key for PVE

On the local Mac:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_pve -C "armagon@pve-goad"
```

### 0.2 -- Add PVE to Known Hosts

```bash
ssh-keyscan -H 192.168.3.213 >> ~/.ssh/known_hosts
```

### 0.3 -- Copy Public Key to PVE

`sshpass` failed due to special characters in the root password. The key was added manually by pasting it into an existing SSH session on PVE:

```bash
# On pve2 (logged in via existing session or console):
echo "ssh-ed25519 AAAA...your-key-here... armagon@pve-goad" >> ~/.ssh/authorized_keys
```

### 0.4 -- Add SSH Config Entry for PVE

Add to `~/.ssh/config` on the local Mac:

```
Host pve
    HostName 192.168.3.213
    User root
    IdentityFile ~/.ssh/id_ed25519_pve
```

Verify:

```bash
ssh pve hostname
# Expected output: pve2
```

### 0.5 -- Generate SSH Key for MrBot

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_mrbot -C "armagon@mrbot"
```

### 0.6 -- Find MrBot's IP Address

MrBot's IP was not known initially. It was discovered from PVE's neighbor table by matching MrBot's MAC address (`bc:24:11:22:50:4c`):

```bash
# On pve2:
ip neigh | grep "bc:24:11:22:50:4c"
# Output: 192.168.3.106
```

### 0.7 -- Copy Public Key to MrBot

Used `sshpass` with the `-e` flag (reads password from `SSHPASS` environment variable) to avoid shell escaping issues:

```bash
export SSHPASS='<mrbot-password>'
sshpass -e ssh-copy-id -i ~/.ssh/id_ed25519_mrbot.pub admin1@192.168.3.106
```

### 0.8 -- Add SSH Config Entry for MrBot

Add to `~/.ssh/config`:

```
Host mrbot
    HostName 192.168.3.106
    User admin1
    IdentityFile ~/.ssh/id_ed25519_mrbot
```

Verify:

```bash
ssh mrbot hostname
# Expected output: MrBot
```

---

## MrBot Provisioning VM Setup

All remaining work is performed on MrBot (via SSH) unless otherwise noted.

### Clone the GOAD Repository

```bash
git clone https://github.com/Orange-Cyberdefense/GOAD.git ~/GOAD
```

### Install System Packages

The `setup_proxmox.sh` script from the GOAD repo failed because `sudo` required the password via stdin and the script did not accommodate this. All steps were run manually instead.

```bash
sudo apt update
sudo apt install -y git vim tmux curl gnupg software-properties-common mkisofs sshpass python3-pip python3-venv python3.12-venv
```

### Install HashiCorp Tools (Packer and Terraform)

```bash
# Add HashiCorp GPG key and repository
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update

# Install Packer and Terraform
sudo apt install -y packer terraform
```

Verify:

```bash
packer --version
# 1.15.0

terraform --version
# 1.14.7
```

### Create Python Virtual Environment and Install Dependencies

```bash
python3 -m venv ~/GOAD/.venv
source ~/GOAD/.venv/bin/activate
```

Install Python packages:

```bash
pip install rich psutil Jinja2 pyyaml ansible_runner pywinrm proxmoxer requests ansible-core==2.18.0 setuptools
```

> **Important version note:** The GOAD `requirements.yml` pins `ansible-core==2.12.6`, which requires Python 3.8. Since MrBot runs Python 3.12, we used `ansible-core==2.18.0` from the `requirements_311.yml` file instead. The `setuptools` package is also required for Python 3.12 compatibility.

### Install Ansible Galaxy Collections

```bash
ansible-galaxy collection install ansible.windows community.windows chocolatey.chocolatey ansible.posix scicore.guacamole community.mysql community.crypto community.general
```

---

## Phase 1: PVE Node Configuration

All commands in this phase are run on pve2 (via `ssh pve` from the local Mac).

### 1.1 -- Create API User and Role

The action plan specified privilege names `VM.Config.CloudInit` (capital "I") and `VM.Monitor`, but these do not exist on this PVE version. The correct names were discovered by inspecting the built-in `PVEVMAdmin` role:

- `VM.Config.CloudInit` must be `VM.Config.Cloudinit` (lowercase "i")
- `VM.Monitor` does not exist; `VM.Console` is the equivalent privilege

Create the role:

```bash
pveum role add GoadInfraRole -privs "Sys.Audit VM.Allocate VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt VM.Audit VM.Console VM.Snapshot Datastore.AllocateSpace Datastore.Audit Pool.Allocate Pool.Audit SDN.Use"
```

Create the user:

```bash
pveum user add infra_as_code@pve --password "password"
```

Assign the role:

```bash
pveum aclmod / -user infra_as_code@pve -role GoadInfraRole
```

> **Security note:** The password `password` was used here. For production environments, use a strong, unique password.

### 1.2 -- Create Resource Pools

```bash
pvesh create /pools --poolid Templates --comment "GOAD Packer templates"
pvesh create /pools --poolid GOAD --comment "GOAD lab VMs"
```

### 1.3 -- Create Isolated Network Bridge (vmbr3)

Read the existing `/etc/network/interfaces` to confirm it had `vmbr0`, `nic0`, `nic1`, `nic2` already configured. Then append the vmbr3 configuration:

```bash
cat >> /etc/network/interfaces << 'EOF'

auto vmbr3
iface vmbr3 inet static
    address 192.168.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up   iptables -t nat -A POSTROUTING -s '192.168.10.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '192.168.10.0/24' -o vmbr0 -j MASQUERADE
#GOAD
EOF
```

Apply the configuration:

```bash
ifreload -a
```

> **Note:** `ifreload` produced ethtool warnings. These are pre-existing and unrelated to the GOAD changes.

Verify:

```bash
ip addr show vmbr3
# Should show: inet 192.168.10.1/24, state UP
```

**Purpose of vmbr3:**

- IP range `192.168.10.0/24` is used for GOAD VMs (avoids conflict with the existing 192.168.3.0/24 network)
- The NAT/masquerade rules give GOAD VMs internet access (needed during Ansible provisioning)
- After provisioning, the NAT rules can be removed to fully isolate the lab
- `vmbr3` is hardcoded in the GOAD Packer HCL files, so this bridge name avoids modifying upstream source

### 1.4 -- Add Second NIC to MrBot (vmbr3)

> **Deviation from plan:** The action plan called for adding a static route on MrBot (`ip route add 192.168.10.0/24 via 192.168.3.213`). Instead, a second NIC was added directly on vmbr3, giving MrBot direct Layer 2 connectivity to the GOAD network. This is cleaner and avoids routing through pve2's vmbr0.

On pve2, add a second NIC to VM 110:

```bash
qm set 110 --net1 virtio,bridge=vmbr3,firewall=0
```

On MrBot, the new interface appears as `ens19` in DOWN state. Bring it up:

```bash
sudo ip link set ens19 up
sudo ip addr add 192.168.10.2/24 dev ens19
```

Verify:

```bash
ping -c 1 192.168.10.1
# PING 192.168.10.1: 1 packets transmitted, 1 received, 0% packet loss
```

Make the configuration persistent via netplan. Create `/etc/netplan/60-goad.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens19:
      addresses:
        - 192.168.10.2/24
```

Fix permissions and apply:

```bash
sudo chmod 600 /etc/netplan/60-goad.yaml
sudo netplan apply
```

Verify the interface survives a reapply:

```bash
sudo netplan apply
ip addr show ens19
# Should show: inet 192.168.10.2/24, state UP
```

---

## Phase 2: Upload ISOs to PVE

### 2.1 -- Windows ISOs and VirtIO Drivers

Four downloads were started in parallel. Two ISOs already existed on PVE:

| ISO | Size | Status |
|-----|------|--------|
| Windows Server 2019 | 5.3 GB | Already present on PVE (from Nov 2022) |
| Windows Server 2016 | 6.5 GB | Downloaded to PVE |
| VirtIO drivers | 754 MB | Already present on PVE |
| Cloudbase-Init MSI | 55 MB | Downloaded to MrBot |

Windows Server 2016 was downloaded directly to PVE's ISO storage:

```bash
# On pve2:
cd /var/lib/vz/template/iso/
wget -O windows_server_2016_14393.0_eval_x64.iso \
  "https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"
```

Cloudbase-Init was downloaded to MrBot:

```bash
# On MrBot:
wget -O ~/GOAD/packer/proxmox/scripts/sysprep/CloudbaseInitSetup_Stable_x64.msi \
  "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
```

> **Note:** Windows 10 ISO was NOT downloaded. It is only needed for the optional `ws01` extension, not for GOAD Full.

### 2.2 -- Scripts ISO

The scripts ISO is built from MrBot and must be copied to PVE (covered in Phase 3 below).

---

## Phase 3: Packer Template Preparation

### 3.0 -- SSH from MrBot to PVE

Generate an SSH key on MrBot for pve2 access, and add it to pve2's authorized_keys:

```bash
# On MrBot:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "mrbot-to-pve2"

# Copy public key to pve2 (method depends on your access)
ssh-copy-id root@192.168.3.213
```

Verify:

```bash
ssh root@192.168.3.213 hostname
# Expected: pve2
```

### 3.1 -- Build Packer ISOs

On MrBot:

```bash
cd ~/GOAD/packer/proxmox/
./build_proxmox_iso.sh
```

This produces 7 ISOs: 6 Autounattend ISOs (for unattended Windows installs) + 1 `scripts_withcloudinit.iso`. The Windows 11 ISO produces a harmless error (not needed for GOAD Full).

Copy the scripts ISO to PVE:

```bash
scp iso/scripts_withcloudinit.iso root@192.168.3.213:/var/lib/vz/template/iso/
```

### 3.2 -- Configure Packer

Create the Packer configuration file on MrBot:

```bash
cd ~/GOAD/packer/proxmox/
cp config.auto.pkrvars.hcl.template config.auto.pkrvars.hcl
```

Edit `config.auto.pkrvars.hcl` with these values:

```hcl
proxmox_url             = "https://192.168.3.213:8006/api2/json"
proxmox_username        = "infra_as_code@pve"
proxmox_password        = "password"
proxmox_skip_tls_verify = "true"
proxmox_node            = "pve2"
proxmox_pool            = "Templates"
proxmox_iso_storage     = "local"
proxmox_vm_storage      = "local"
```

> **Critical: `proxmox_vm_storage` must be `local`, NOT `local-lvm`.** The Packer variable files specify `vm_disk_format = "qcow2"`, and LVM-thin storage (`local-lvm`) only supports `raw` format. The `local` directory storage supports qcow2. When GOAD's Terraform later deploys lab VMs to `local-lvm` using linked clones, format conversion is handled automatically.

### 3.3 -- Initialize Packer Plugins

```bash
cd ~/GOAD/packer/proxmox/
packer init .
```

This installed the Proxmox provider plugin v1.2.3.

### 3.4 -- Fix Permission and Storage Issues (Pre-Build)

Three issues were discovered and fixed before the Packer build could succeed:

**Issue 1: Missing `Datastore.AllocateTemplate` privilege**

Packer needs to upload autounattend ISOs and convert VMs to templates. The initial role was missing this privilege:

```bash
# On pve2:
pveum role modify GoadInfraRole -privs "Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Use,Sys.Audit,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Snapshot"
```

**Issue 2: `local` storage missing `images` content type**

The `local` directory storage only had `import,backup,vztmpl,iso` content types. Packer needs to create VM disk images (qcow2):

```bash
# On pve2:
pvesm set local --content import,backup,vztmpl,iso,images
```

**Issue 3: `vlan_tag = "10"` incompatible with portless bridge**

The Packer template hardcoded `vlan_tag = "10"` in the network adapter config. QEMU failed to start because vmbr3 has `bridge-ports none` — PVE's bridge script cannot create a VLAN tap device on a bridge with no physical interface.

Since vmbr3 is already an isolated bridge dedicated to GOAD, the VLAN tag is redundant. Removed it from the Packer template:

```bash
# On MrBot:
sed -i '/vlan_tag = "10"/d' ~/GOAD/packer/proxmox/packer.json.pkr.hcl
```

> **Note:** The Terraform configs also use VLAN tagging (`pm_vlan = 10`). This will need to be addressed in Phase 4 when configuring `goad.ini`.

**Issue 4: No DHCP server on vmbr3**

Windows VMs boot with DHCP enabled by default. With no DHCP server on vmbr3, Windows fell back to APIPA (169.254.x.x), which is unreachable from MrBot's 192.168.10.0/24 subnet. Packer needs to discover the VM's IP via the QEMU guest agent to connect over WinRM.

Installed and configured dnsmasq on pve2 as a DHCP server for vmbr3:

```bash
# On pve2:
apt-get install -y dnsmasq

cat > /etc/dnsmasq.d/goad-vmbr3.conf << 'EOF'
interface=vmbr3
bind-interfaces
dhcp-range=192.168.10.100,192.168.10.200,255.255.255.0,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,192.168.10.1
no-resolv
server=8.8.8.8
server=1.1.1.1
EOF

systemctl restart dnsmasq
```

**Issue 5: Missing `VM.GuestAgent.Audit` and `VM.GuestAgent.Unrestricted` privileges**

Packer queries the QEMU guest agent via the Proxmox API to discover the VM's IP for WinRM connection. These are newer PVE privileges (not in common GOAD documentation). Without them, Packer silently retries forever with `403 Permission check failed`.

```bash
# On pve2 — final privilege set for GoadInfraRole:
pveum role modify GoadInfraRole -privs "Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Use,Sys.Audit,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Snapshot,VM.GuestAgent.Audit,VM.GuestAgent.Unrestricted"
```

**Issue 6: Windows Defender quarantining Packer elevated scripts**

Packer's `elevated_user`/`elevated_password` mechanism uploads PowerShell scripts to `C:\Windows\Temp` and runs them via scheduled tasks. Windows Defender on Server 2019 quarantined these temp scripts before the scheduled task could execute them, causing the CloudBase-Init provisioner to silently fail.

Fixed by adding a Defender exclusion to the autounattend as a FirstLogonCommands entry (Order 0, before all other commands):

```xml
<SynchronousCommand wcm:action="add">
    <CommandLine>cmd.exe /c powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true; Add-MpPreference -ExclusionPath C:\Windows\Temp"</CommandLine>
    <Description>Disable Windows Defender realtime monitoring for Packer</Description>
    <Order>0</Order>
    <RequiresUserInput>true</RequiresUserInput>
</SynchronousCommand>
```

Applied to both Server 2019 and Server 2016 autounattend files, then rebuilt the ISOs:

```bash
# On MrBot:
cd ~/GOAD/packer/proxmox/
# Edit answer_files/2019_proxmox_cloudinit/Autounattend.xml (add above block)
# Edit answer_files/2016_proxmox_cloudinit/Autounattend.xml (add above block)
./build_proxmox_iso.sh  # Rebuilds ISOs and updates checksums in pkvars files
```

> **Sub-issue:** The initial Defender fix used `<Order>0</Order>` which is invalid — Windows FirstLogonCommands must start at 1. This caused "Windows could not complete the installation." Fixed by using `<Order>1</Order>` and incrementing all subsequent orders.

**Issue 7: Packer elevated command wrapper fails on Proxmox**

Even with Defender disabled, Packer's `elevated_user`/`elevated_password` mechanism still failed. This mechanism uploads scripts to `C:\Windows\Temp`, then creates a Windows Scheduled Task to execute them under the specified user. The scheduled task consistently could not find the script files at execution time:

```
& : The term 'c:/Windows/Temp/script-69b508c6-...ps1' is not recognized as the name of a
cmdlet, function, script file, or operable program.
```

This is a known incompatibility between the Packer PowerShell provisioner's elevated command wrapper and certain QEMU/Proxmox environments. The elevated wrapper is designed to bypass UAC, but since the GOAD autounattend already disables UAC (`<EnableLUA>false</EnableLUA>`), the wrapper is unnecessary.

**Fix:** Remove `elevated_user` and `elevated_password` from both provisioner blocks in `packer.json.pkr.hcl`:

```bash
# On MrBot:
sed -i '/elevated_password/d; /elevated_user/d' ~/GOAD/packer/proxmox/packer.json.pkr.hcl
```

This makes Packer execute scripts directly over WinRM as the vagrant user, who is already an administrator with UAC disabled.

### 3.5 -- Build Templates

```bash
cd ~/GOAD/packer/proxmox/

# Build Windows Server 2019 template
packer build -var-file=windows_server2019_proxmox_cloudinit.pkvars.hcl .
# Result: Template ID 107, completed in 7 min 16 sec

# Build Windows Server 2016 template
packer build -var-file=windows_server2016_proxmox_cloudinit.pkvars.hcl .
# Result: Template ID 116, completed in 6 min 14 sec
```

Both templates built successfully:

| Template | VM ID | Build Time |
|----------|-------|------------|
| Windows Server 2019 | **107** | 7 min 16 sec |
| Windows Server 2016 | **116** | 6 min 14 sec |

---

## Phase 4: Configure GOAD

### 4.1 -- Keyboard Layout

Changed the default keyboard layout from French to US English in `globalsettings.ini`:

```bash
# On MrBot:
sed -i 's/keyboard_layouts=\["0000040C", "00000409"\]/keyboard_layouts=\["00000409", "0000040C"\]/' ~/GOAD/globalsettings.ini
```

The first entry in the list becomes the default layout. US English (`00000409`) is now first; French (`0000040C`) remains available as a secondary layout.

### 4.2 -- Create goad.ini

Created `~/.goad/goad.ini` on MrBot:

```ini
[default]
lab = GOAD
provider = proxmox
provisioner = local
ip_range = 192.168.10

[proxmox]
pm_api_url = https://192.168.3.213:8006/api2/json
pm_user = infra_as_code@pve
pm_pass = password
pm_node = pve2
pm_pool = GOAD
pm_full_clone = false
pm_storage = local-lvm
pm_vlan = 0
pm_network_bridge = vmbr3
pm_network_model = e1000

[proxmox_templates_id]
WinServer2019_x64 = 107
WinServer2016_x64 = 116
```

Key decisions:

- **`ip_range = 192.168.10`** -- Matches the vmbr3 subnet (192.168.10.0/24). VMs will get IPs like 192.168.10.10 (DC01), 192.168.10.11 (DC02), etc.
- **`pm_pass = password`** -- Required for non-interactive execution (deviation #25). Without it, `getpass()` blocks in tmux/automation. The config key is `pm_pass` (not `pm_password`).
- **`pm_vlan = 0`** -- Disables VLAN tagging (deviation #20). vmbr3 has `bridge-ports none` so VLAN tagging is incompatible. Setting to 0 tells the Terraform provider to omit the VLAN tag.
- **`pm_storage = local-lvm`** -- Templates were moved to `local-lvm` (816 GB LVM-thin) to avoid filling the 94 GB root partition (deviation #23). See Issue 11 in Phase 5.3.
- **`pm_full_clone = false`** -- Uses linked clones (faster, less disk space).
- **Template IDs** -- From the Phase 3 Packer builds: 107 (Server 2019), 116 (Server 2016).

### GOAD Full VM Layout

| VM | Name | IP | Memory | Cores | OS | Role |
|----|------|----|--------|-------|----|------|
| DC01 | kingslanding | 192.168.10.10 | 3096 MB | 2 | Server 2019 | DC for sevenkingdoms.local |
| DC02 | winterfell | 192.168.10.11 | 3096 MB | 2 | Server 2019 | DC for north.sevenkingdoms.local |
| DC03 | meereen | 192.168.10.12 | 3096 MB | 2 | Server 2016 | DC for essos.local |
| SRV02 | castelblack | 192.168.10.22 | 6240 MB | 2 | Server 2019 | MSSQL + IIS |
| SRV03 | braavos | 192.168.10.23 | 5120 MB | 2 | Server 2016 | MSSQL + ADCS |

**Total resources:** 10 cores, ~20.6 GB RAM, ~200 GB disk.

---

## Phase 5: Deploy GOAD

### 5.1 -- Pre-Deploy Fixes

**Issue 8: Missing Azure and AWS Python packages**

GOAD imports all provider modules at startup, regardless of the selected provider. The initial venv only had Proxmox-related packages:

```bash
# On MrBot:
source ~/GOAD/.venv/bin/activate
pip install azure-identity azure-mgmt-compute azure-mgmt-network boto3
```

**Issue 9: `goad.sh` venv path mismatch**

`goad.sh` expects a venv at `~/.goad/.venv` (not `~/GOAD/.venv`). Rather than creating a duplicate venv, symlinked the existing one:

```bash
ln -s ~/GOAD/.venv ~/.goad/.venv
```

**Issue 10: `pm_pass` config key needed**

The Proxmox provider code reads the password from `pm_pass` (not `pm_password`). Without it, `getpass` prompts interactively, which blocks automation. Added `pm_pass = password` to `~/.goad/goad.ini`.

The Terraform `pm_password` variable was provided via environment variable:

```bash
export TF_VAR_pm_password=password
```

### 5.2 -- Terraform (First Deploy — Later Replaced)

> **Note:** This first deploy used `pm_storage = local` (wrong partition). It was destroyed and redeployed in Sections 5.3-5.4. Documented here for the troubleshooting record.

The GOAD installer is interactive. It prompts twice before Terraform runs:

1. `Create lab with theses settings ? (y/N)` — confirm lab configuration
2. `Enter a value:` — Terraform `apply` confirmation (type `yes`)

To avoid the Terraform password prompt, set `TF_VAR_pm_password` as an environment variable:

```bash
cd ~/GOAD
source .venv/bin/activate
export TF_VAR_pm_password=password
python3 goad.py -t install -l GOAD -p proxmox -m local
```

Terraform created all 5 VMs as linked clones from the templates in ~40 seconds:

| VM | Name | VM ID | Template | IP |
|----|------|-------|----------|----|
| DC01 | kingslanding | 119 | 107 (Server 2019) | 192.168.10.10 |
| DC02 | winterfell | 118 | 107 (Server 2019) | 192.168.10.11 |
| DC03 | meereen | 121 | 116 (Server 2016) | 192.168.10.12 |
| SRV02 | castelblack | 117 | 107 (Server 2019) | 192.168.10.22 |
| SRV03 | braavos | 120 | 116 (Server 2016) | 192.168.10.23 |

Instance workspace: `~/GOAD/workspace/fa05ca-goad-proxmox/`

The workspace contains: rendered Terraform configs, Terraform state, Ansible inventory, and SSH keys. A new workspace is created for each `install` run.

**Boot timing issue:** On the first Ansible run, the Server 2019 VMs (dc01, dc02, srv02) were `UNREACHABLE` with `No route to host` errors on WinRM port 5986. The Server 2016 VMs (dc03, srv03) connected successfully. This was a boot timing issue — the 2019 VMs needed more time to initialize WinRM after cloning. GOAD automatically retries the `build.yml` playbook on failure, and all VMs connected on the second run. No manual intervention was needed.

> **Tip:** If you see UNREACHABLE errors on the first Ansible run, check if the VMs are still booting. GOAD's retry mechanism will re-run the playbook automatically.

### 5.3 -- Storage Fix: Move to local-lvm

**Issue 11: VM disks deployed to wrong storage**

The initial deploy placed all VM disks on `local` (94 GB root partition) instead of `local-lvm` (816 GB LVM-thin). With 5 × 40 GB VMs plus templates and ISOs, the root partition would run out of space.

**Fix:**

1. Stopped Ansible, destroyed the 5 VMs via Terraform
2. Moved template disks from `local` to `local-lvm` (automatically converts qcow2 → raw):

```bash
# On pve2:
qm move-disk 107 sata0 local-lvm --delete 1
qm move-disk 116 sata0 local-lvm --delete 1
```

3. Updated `~/.goad/goad.ini`:

```ini
pm_storage = local-lvm
```

4. Removed old workspace and redeployed

### 5.4 -- Second Deploy (Terraform)

Terraform recreated all 5 VMs, now on `local-lvm`:

| VM | Name | VM ID | Storage | IP |
|----|------|-------|---------|-----|
| DC01 | kingslanding | 120 | local-lvm | 192.168.10.10 |
| DC02 | winterfell | 121 | local-lvm | 192.168.10.11 |
| DC03 | meereen | 118 | local-lvm | 192.168.10.12 |
| SRV02 | castelblack | 117 | local-lvm | 192.168.10.22 |
| SRV03 | braavos | 119 | local-lvm | 192.168.10.23 |

### 5.5 -- Ansible Provisioning

Ansible runs multiple playbooks sequentially via GOAD's orchestrator:

| Playbook | Purpose |
|----------|---------|
| `build.yml` | Base config: hostname, admin password, keyboard, RDP, firewall |
| `ad-servers.yml` | Create domain controllers and enroll servers |
| `ad-parent_domain.yml` | Promote dc01 + dc03 as forest root DCs |
| `ad-child_domain.yml` | Promote dc02 as child DC (north.sevenkingdoms.local) |
| `wait5m.yml` | Wait for AD replication to settle |
| `ad-members.yml` | Join srv02 + srv03 to their domains |
| `ad-trusts.yml` | Create forest trust (sevenkingdoms ↔ essos) |
| `ad-data.yml` | Create users, groups, OUs |
| `ad-gmsa.yml` | Group Managed Service Accounts |
| `laps.yml` | LAPS configuration |
| `ad-relations.yml` | Group memberships, delegations |
| `adcs.yml` | Certificate Services on dc01 and srv03 |
| `ad-acl.yml` | ACL misconfigurations (attack paths) |
| `servers.yml` | IIS, MSSQL, SSMS, WebDAV, linked servers |
| `security.yml` | Security policies, Defender, Windows Updates |
| `vulnerabilities.yml` | Intentional vulns (ADCS ESC templates, pentesting targets) |

**Issue 12: Ansible process silently died during `servers.yml`**

The first Ansible run (deploy2) silently died during the `servers.yml` playbook while installing IIS Web-Server with sub-features on srv02. No OOM error, no fatal error in the log — the process simply stopped. The likely cause was a WinRM timeout during the long-running Windows feature install, combined with `tee` pipe buffering masking the real-time output.

By the time the process died, 14 of 16 playbooks had completed successfully (everything up to and including `ad-acl.yml`, plus a partial `servers.yml`).

**Fix:** Resumed from where it left off using the `-a true` (ansible-only) flag to skip Terraform, and `stdbuf -oL` for line-buffered output:

```bash
ssh mrbot
tmux new-session -d -s goad "cd ~/GOAD && source .venv/bin/activate && \
  export TF_VAR_pm_password=password && \
  python3 goad.py -t install -l GOAD -p proxmox -m local -a true -i 18b7fb-goad-proxmox \
  2>&1 | stdbuf -oL tee -a ~/.goad/deploy2.log; echo DEPLOY_DONE; exec bash"
```

> **Note:** The `-a true` flag reruns all playbooks from scratch (GOAD has no checkpoint/resume), but Ansible tasks are idempotent — already-completed work shows `ok` and is skipped quickly. The `-i 18b7fb-goad-proxmox` flag specifies the existing instance workspace so Terraform state and inventory are reused.

The retry ran through all 16 playbooks. The `servers.yml` playbook triggered GOAD's automatic retry mechanism once (expected — boot timing after reboots), then completed successfully on the second pass. All playbooks completed with zero failures:

```
PLAY RECAP (vulnerabilities.yml — final playbook):
dc01  — ok=15, changed=4,  failed=0
dc02  — ok=31, changed=13, failed=0
dc03  — ok=16, changed=7,  failed=0
srv02 — ok=18, changed=10, failed=0
srv03 — ok=17, changed=11, failed=0

Lab successfully provisioned in 00:28:10
```

Instance workspace: `~/GOAD/workspace/18b7fb-goad-proxmox/`

### Monitoring the Deploy

**Live monitoring:**

```bash
ssh mrbot
tmux attach -t goad
# Detach without killing: Ctrl+B then D
```

**Log file:** `~/.goad/deploy2.log` (on MrBot)

**Check if process is running:**

```bash
ssh mrbot 'pgrep -f "ansible-playbook\|goad.py"'
```

**GOAD retry behavior:** If an Ansible playbook fails (e.g., VMs unreachable during reboot), GOAD re-runs `build.yml` from the beginning. Most tasks are idempotent, so re-running is safe. However, this means a failure late in the process restarts from scratch. Monitor for repeated failures.

**Check which playbook is currently running:**

```bash
ssh mrbot 'grep "Running command" ~/.goad/deploy2.log | tail -1'
```

---

## Phase 6: Post-Install Verification

After Ansible reported `Lab successfully provisioned`, the following checks were performed from MrBot to verify the deployment matches the GOAD playbook definitions.

### 6.1 -- Infrastructure Checks

| Check | Result | Details |
|-------|--------|---------|
| GOAD instance status | `installed` | Instance `18b7fb-goad-proxmox` |
| Terraform found | OK | In PATH |
| Ansible found | OK | In PATH, galaxy collections installed |

### 6.2 -- Network and Connectivity

| VM | IP | Ping | WinRM (5986) |
|----|-----|------|--------------|
| dc01 (kingslanding) | 192.168.10.10 | OK | OK |
| dc02 (winterfell) | 192.168.10.11 | OK | OK |
| dc03 (meereen) | 192.168.10.12 | OK | OK |
| srv02 (castelblack) | 192.168.10.22 | OK | OK |
| srv03 (braavos) | 192.168.10.23 | OK | OK |

### 6.3 -- DNS Resolution

All domain names and hostnames resolved correctly via dc01 (192.168.10.10):

| Query | Resolves To |
|-------|-------------|
| sevenkingdoms.local | 192.168.10.10 |
| north.sevenkingdoms.local | 192.168.10.11 |
| essos.local | 192.168.10.12 |
| kingslanding.sevenkingdoms.local | 192.168.10.10 |
| winterfell.north.sevenkingdoms.local | 192.168.10.11 |
| meereen.essos.local | 192.168.10.12 |
| castelblack.north.sevenkingdoms.local | 192.168.10.22 |
| braavos.essos.local | 192.168.10.23 |

### 6.4 -- Active Directory Domains and Trusts

**Forest: sevenkingdoms.local**

| Property | Value |
|----------|-------|
| Forest domains | sevenkingdoms.local, north.sevenkingdoms.local |
| Trusts from dc01 | north.sevenkingdoms.local (BiDirectional, Uplevel), essos.local (BiDirectional, Uplevel) |
| Trusts from dc03 | sevenkingdoms.local (BiDirectional, Uplevel) |

**Domain Admin Membership (verified):**

| Domain | Domain Admins |
|--------|---------------|
| sevenkingdoms.local | Administrator, cersei.lannister, robert.baratheon |
| north.sevenkingdoms.local | Administrator, eddard.stark |
| essos.local | Administrator, daenerys.targaryen, QueenProtector (group) |

### 6.5 -- User Accounts

| Domain | User Count | Key Accounts Verified |
|--------|------------|----------------------|
| sevenkingdoms.local | 18 | tywin.lannister, jaime.lannister, cersei.lannister, tyron.lannister, robert.baratheon, joffrey.baratheon, renly.baratheon, stannis.baratheon, petyer.baelish, lord.varys, maester.pycelle |
| north.sevenkingdoms.local | 18 | arya.stark, eddard.stark, catelyn.stark, robb.stark, sansa.stark, brandon.stark, rickon.stark, hodor, jon.snow, samwell.tarly, jeor.mormont, sql_svc |
| essos.local | All present | daenerys.targaryen, viserys.targaryen, khal.drogo, jorah.mormont, missandei, drogon, sql_svc |

### 6.6 -- Groups (essos.local sample)

All expected groups verified: greatmaster, Targaryen, Dothraki, Dragons, QueenProtector, DragonsFriends, Spys.

### 6.7 -- Services

| Service | Host | Status |
|---------|------|--------|
| IIS (W3SVC) | srv02 | Running |
| MSSQL Express (MSSQL$SQLEXPRESS) | srv02 | Running |
| MSSQL Express (MSSQL$SQLEXPRESS) | srv03 | Running |
| ADCS (CertSvc) | dc01 | Running |
| ADCS (CertSvc) | srv03 | Running |
| WebDAV (WebClient) | srv02 | Installed (Stopped — expected) |
| WebDAV (WebClient) | srv03 | Installed (Stopped — expected) |

### 6.8 -- MSSQL Configuration

**Linked Servers on srv02 (castelblack):**

| Server Name | Description |
|-------------|-------------|
| BRAAVOS | Linked to braavos.essos.local |
| CASTELBLACK\SQLEXPRESS | Local instance |

**SPNs on sql_svc (north.sevenkingdoms.local):**
- `MSSQLSvc/castelblack.north.sevenkingdoms.local`
- `MSSQLSvc/castelblack.north.sevenkingdoms.local:1433`

### 6.9 -- ADCS Certificate Templates (essos.local)

Vulnerable ESC templates confirmed on essos.local:

| Template | Present |
|----------|---------|
| ESC1 | Yes |
| ESC2 | Yes |
| ESC3 | Yes |
| ESC3-CRA | Yes |
| ESC4 | Yes |
| ESC9 | Yes |
| ESC13 | Yes |

### 6.10 -- LAPS

LAPS verified on essos.local domain:

| Computer | LAPS Password Set |
|----------|-------------------|
| MEEREEN (dc03) | No (DC — expected) |
| BRAAVOS (srv03) | Yes (`Ul9BVl)7fda$e+`) |

### 6.11 -- Verification Summary

All checks pass. The deployment matches the GOAD playbook definitions:
- 3 AD domains across 2 forests with bidirectional trusts
- All Game of Thrones-themed users, groups, and OUs created
- MSSQL with linked servers and impersonation configured
- ADCS with 7 ESC vulnerability templates
- IIS and WebDAV installed
- LAPS deployed
- All services running on expected hosts

---

## Backups to NAS

Before making changes, backups of critical VMs and PVE configuration were taken to the NAS.

### NAS Connectivity

Tested SMB connectivity:

```bash
smbclient //192.168.3.253/folder216 -U 'MrShare%<password>'
```

Created a `pve-backups` directory on the NAS share via smbclient.

### Add NAS as PVE Backup Storage

On pve2, added the NAS as a CIFS backup storage target:

```bash
pvesm add cifs nas-backup --server 192.168.3.253 --share folder216 \
  --username MrShare --password <password> --subdir /pve-backups \
  --content backup
```

### PVE Configuration Backup

Created a tarball of PVE configuration files:

```bash
tar czf /tmp/pve-config-20260313.tar.gz /etc/pve/ /etc/network/interfaces /etc/hosts
```

This was uploaded to `nas-backup` storage under `pve-backups/config/`.

### VM Backups

Initial attempts to backup VMs 110 (MrBot) and 111 (Tier-Model-DC) were started but cancelled by the operator. The targets were changed to HAOS (VM 112) and WebApp1 (VM 103), which reside on pve3.

**First attempt** to backup cross-node VMs using `vzdump --node pve3` from pve2 produced empty output (silently failed).

**Successful method** -- used the PVE API instead:

```bash
# HAOS (VM 112 on pve3)
pvesh create /nodes/pve3/vzdump --vmid 112 --storage nas-backup --mode snapshot --compress zstd
# Result: 2.97 GB archive, completed in 35 seconds

# WebApp1 (VM 103 on pve3)
pvesh create /nodes/pve3/vzdump --vmid 103 --storage nas-backup --mode snapshot --compress zstd
# Result: 6.25 GB archive, completed in 63 seconds
```

> **Lesson learned:** When backing up VMs on a remote cluster node, use `pvesh create /nodes/<remote-node>/vzdump` rather than `vzdump --node <remote-node>`. The latter can silently fail.

---

## Changes from Plan

The following table lists every deviation from the original action plan (`GOAD-PVE-ACTION-PLAN.md`) and the reason for each.

### Structural Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 1 | Phase 0 only covers MrBot-to-PVE SSH | SSH setup was done in a broader scope: local Mac to PVE, local Mac to MrBot, and MrBot to PVE | The local Mac is the orchestration point; SSH access from it was a prerequisite not covered in the plan |
| 2 | No backup phase mentioned | Full backup phase executed (PVE config + VMs to NAS) | Good practice before making infrastructure changes |

### Phase 1 Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 3 | Role privilege `VM.Config.CloudInit` (capital "I") | Used `VM.Config.Cloudinit` (lowercase "i") | The plan had the wrong case. PVE rejects `VM.Config.CloudInit`; the actual privilege name uses lowercase "i" |
| 4 | Role privilege `VM.Monitor` | Used `VM.Console` instead | `VM.Monitor` does not exist on this PVE version. `VM.Console` is the correct equivalent |
| 5 | Role did not include `VM.Snapshot` | Added `VM.Snapshot` to the role | Needed for Packer/Terraform snapshot operations |
| 6 | Action 1.4: Add static route on MrBot (`ip route add 192.168.10.0/24 via 192.168.3.213`) | Added a second NIC (net1) to MrBot on vmbr3, with IP 192.168.10.2/24 | Direct L2 connectivity is cleaner than routing through pve2's vmbr0. Suggested by the operator as a better approach |
| 7 | Static route persistence via netplan route entry | Netplan config for second NIC at `/etc/netplan/60-goad.yaml` | Consequence of deviation #6 -- a NIC config replaces a route config |

### MrBot Setup Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 8 | Run `setup_proxmox.sh` to install dependencies | Ran all steps manually | The script failed because `sudo` required the password via stdin and the script did not handle this |
| 9 | `requirements.yml` pins `ansible-core==2.12.6` | Installed `ansible-core==2.18.0` | Python 3.12 on MrBot (Ubuntu 24.04) is incompatible with ansible-core 2.12.6. The project's `requirements_311.yml` file specifies 2.18.0 for Python 3.11+ |
| 10 | No mention of `setuptools` package | Installed `setuptools` explicitly | Required for Python 3.12 compatibility (also listed in `requirements_311.yml`) |

### Phase 2 Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 11 | Plan implies downloading all ISOs fresh | Windows Server 2019 and VirtIO ISOs already existed on PVE | They were uploaded in a previous session (Nov 2022). No re-download needed |

### Phase 3 Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 12 | No deviation in Packer config values | Config matches plan exactly | N/A |
| 13 | Role did not include `Datastore.AllocateTemplate` | Added `Datastore.AllocateTemplate` to GoadInfraRole | Packer uploads autounattend ISOs and converts VMs to templates — needs this privilege on `local` storage |
| 14 | `local` storage has default content types only | Added `images` content type to `local` storage | Packer creates qcow2 disk images; `local` storage needed `images` in its content list |
| 15 | Packer template uses `vlan_tag = "10"` on vmbr3 | Removed `vlan_tag = "10"` from `packer.json.pkr.hcl` | vmbr3 has `bridge-ports none`; PVE cannot create VLAN tap devices on a portless bridge. VLAN tagging is redundant since vmbr3 is already isolated |
| 16 | Plan does not mention DHCP on vmbr3 | Installed dnsmasq on pve2 as DHCP server for vmbr3 (192.168.10.100-200) | Windows VMs get APIPA addresses without DHCP; Packer needs a routable IP to connect via WinRM |
| 17 | Role did not include guest agent privileges | Added `VM.GuestAgent.Audit` and `VM.GuestAgent.Unrestricted` to GoadInfraRole | Packer queries QEMU guest agent via PVE API to discover VM IP. These privileges are newer and not in common GOAD docs |
| 18 | No Windows Defender exclusion in autounattend | Added Defender realtime disable (Order 1) to both 2019 and 2016 autounattend files, rebuilt ISOs | Precautionary — prevents Defender from interfering with Packer provisioner scripts |
| 19 | Packer provisioners use `elevated_user`/`elevated_password` | Removed elevated command wrapper from both provisioners in `packer.json.pkr.hcl` | The elevated wrapper (Scheduled Task mechanism) consistently fails on Proxmox — uploaded scripts vanish before execution. UAC is already disabled in the autounattend, so elevation is unnecessary |

### Phase 4 Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 20 | `pm_vlan = 10` (default) | Set `pm_vlan = 0` to disable VLAN tagging | Same issue as deviation #15 — vmbr3 has `bridge-ports none`, VLAN tagging is incompatible and unnecessary on an already-isolated bridge |
| 24 | Default keyboard layout is French (`0000040C`) first, US English (`00000409`) second | Changed to US English first, French second in `globalsettings.ini` | The operator uses a UK/US English keyboard. The default French layout causes wrong key mappings for passwords and commands when accessing VMs via console or RDP |

### Phase 5 Deviations

| # | Plan | Actual | Reason |
|---|------|--------|--------|
| 21 | `goad.sh` creates its own venv at `~/.goad/.venv` | Symlinked existing venv (`~/GOAD/.venv → ~/.goad/.venv`) | Avoided redundant package installation; existing venv already had all dependencies |
| 22 | Requirements file does not list Azure/AWS packages as optional | Installed `azure-identity`, `azure-mgmt-compute`, `azure-mgmt-network`, `boto3` | GOAD imports all provider modules at startup regardless of which provider is selected — missing Azure/AWS packages cause ImportError |
| 23 | `pm_storage = local` (initial deploy) | Changed to `pm_storage = local-lvm`, moved templates via `qm move-disk` | Root partition (`local`) is only 94 GB — too small for 5 × 40 GB VMs. `local-lvm` has 816 GB on a dedicated LVM-thin pool |
| 25 | `pm_pass` not mentioned in GOAD documentation | Added `pm_pass = password` to `goad.ini` and set `TF_VAR_pm_password` env var | Without `pm_pass`, the Proxmox provider calls `getpass()` which blocks non-interactive/tmux execution. The config key name is `pm_pass` (not `pm_password`) |
| 26 | Ansible expected to run to completion in one pass | Process silently died during `servers.yml` (IIS install); resumed with `-a true` flag and `stdbuf -oL tee` | Likely WinRM timeout during long-running Windows feature install. `stdbuf -oL` fixes tee buffering so real-time output is visible in tmux. Ansible idempotency means re-running all playbooks is safe |

### Total Deviations: 26

Of the 26 deviations from the original plan, the most impactful categories were:
- **PVE privileges** (5 deviations): GOAD documentation does not list all required privileges for newer PVE versions
- **VLAN/network** (3 deviations): VLAN tagging is incompatible with portless bridges; DHCP is required but undocumented
- **Packer on Proxmox** (3 deviations): Elevated command wrapper, Defender interference, and guest agent privileges
- **Storage** (2 deviations): `local` vs `local-lvm` sizing, content types
- **Python/package compatibility** (3 deviations): Python 3.12, Azure/AWS imports, setuptools
- **Keyboard/locale** (1 deviation): French default layout changed to US English
- **Operational** (2 deviations): `pm_pass` key undocumented, Ansible process crash during long Windows installs

---

## Quick Reference: File Locations

| File | Host | Path |
|------|------|------|
| SSH key (Mac to PVE) | Local Mac | `~/.ssh/id_ed25519_pve` |
| SSH key (Mac to MrBot) | Local Mac | `~/.ssh/id_ed25519_mrbot` |
| SSH config | Local Mac | `~/.ssh/config` |
| GOAD repo | MrBot | `~/GOAD/` |
| Python venv | MrBot | `~/GOAD/.venv` |
| Packer config | MrBot | `~/GOAD/packer/proxmox/config.auto.pkrvars.hcl` |
| GOAD config | MrBot | `~/.goad/goad.ini` |
| GOAD venv (symlink) | MrBot | `~/.goad/.venv → ~/GOAD/.venv` |
| GOAD workspace | MrBot | `~/GOAD/workspace/<instance-id>/` |
| Deploy log | MrBot | `~/.goad/deploy2.log` |
| Instance workspace | MrBot | `~/GOAD/workspace/18b7fb-goad-proxmox/` |
| Ansible playbooks | MrBot | `~/GOAD/ansible/` |
| dnsmasq config | pve2 | `/etc/dnsmasq.d/goad-vmbr3.conf` |
| Netplan GOAD config | MrBot | `/etc/netplan/60-goad.yaml` |
| PVE network config | pve2 | `/etc/network/interfaces` |
| ISOs | pve2 | `/var/lib/vz/template/iso/` |
| PVE config backup | NAS | `folder216/pve-backups/config/pve-config-20260313.tar.gz` |
| HAOS backup | NAS | `folder216/pve-backups/dump/` (vzdump archive, VM 112) |
| WebApp1 backup | NAS | `folder216/pve-backups/dump/` (vzdump archive, VM 103) |

---

## Reliability Measures for Long-Running Installs

GOAD's Ansible provisioning includes several long-running tasks (IIS feature installation, MSSQL setup, Exchange Server install) that can take 10-45+ minutes per task. These are prone to silent failures due to WinRM timeouts and output buffering. The following measures ensure a smooth install.

### Line-Buffered Output

By default, piping Ansible output through `tee` causes buffering — you won't see output in real-time, and if the process dies you won't know until you check manually.

**Fix:** Always prefix with `stdbuf -oL` to force line-buffered output:

```bash
python3 goad.py -t install ... 2>&1 | stdbuf -oL tee -a ~/.goad/deploy.log
```

### Idempotent Resume After Crash

If Ansible dies mid-run (WinRM timeout, OOM, SSH disconnect), you can safely resume without re-running Terraform:

```bash
python3 goad.py -t install -l GOAD -p proxmox -m local -a true -i <instance-id> 2>&1 | stdbuf -oL tee -a ~/.goad/deploy.log
```

The `-a true` flag skips the Terraform provide step and runs only Ansible. Because Ansible tasks are idempotent, already-completed tasks will be skipped quickly and provisioning resumes from the point of failure.

### Extension Checkpoint Files

The Exchange extension uses checkpoint markers to avoid re-running completed stages:

- **Prereq marker:** `C:\exchange\exchange_prereqs_complete.txt` — created after all prerequisites (.NET, Visual C++, UCMA, IIS features) are installed. If this file exists, the prereq block is skipped entirely on retry.
- **Service check:** The role checks for the `MSExchangeFrontendTransport` Windows service at the start. If Exchange is already installed, all install tasks are skipped.

This means you can safely re-run the extension install after a crash — it will pick up where it left off.

### tmux for Session Persistence

Always run deploys inside a tmux session on MrBot to survive SSH disconnects:

```bash
tmux new-session -d -s goad "cd ~/GOAD && source .venv/bin/activate && export TF_VAR_pm_password=password && python3 goad.py ... 2>&1 | stdbuf -oL tee -a ~/.goad/deploy.log; echo DEPLOY_DONE; exec bash"
```

Monitor: `tmux attach -t goad` (detach with `Ctrl+b d`)

### Pre-Deploy Backups

Before major changes (new extensions, storage migrations), back up all GOAD VMs to the NAS:

```bash
ssh root@192.168.3.213 "vzdump 117 118 119 120 121 --storage nas-backup --compress zstd --mode snapshot"
```

Snapshot-mode backups run without stopping VMs and take ~2 minutes each.

---

## Phase 7: Exchange Extension

### 7.1 Pre-Flight Fixes

The Exchange extension's Proxmox terraform template (`extensions/exchange/providers/proxmox/windows.tf`) had bugs that would have caused the install to fail:

| Issue | Original Value | Fixed Value |
|-------|---------------|-------------|
| Clone template | `Ubuntu_2404_x64` (wrong OS!) | `WinServer2019_x64` |
| Memory | `12000` | `8192` (Exchange 2019 minimum is 8 GB) |
| Description | `{{ip_range}}.10` (wrong IP) | `{{ip_range}}.21` |

### 7.2 Deploying the Extension

The Exchange extension must be installed via the GOAD interactive CLI (not command-line flags):

```bash
# On MrBot, in tmux
cd ~/GOAD && source .venv/bin/activate
export TF_VAR_pm_password=password
python3 goad.py

# In the GOAD console:
# (instance loads automatically if set as default)
install_extension exchange
# Approve Terraform with "yes" when prompted
```

This creates VM 122 (SRV01 / the-eyrie) on `192.168.10.21` and runs the Exchange Ansible playbook.

### 7.3 What the Extension Deploys

| Step | Description | Duration |
|------|-------------|----------|
| Terraform | Clone SRV01 from template 107, 4 cores, 8 GB RAM | ~1 min |
| AD data update | Add Arryn users/groups to sevenkingdoms.local (DC01) | ~2 min |
| Server setup | Common config, keyboard, hostname, domain join | ~5 min |
| ISO download | Exchange 2019 CU9 ISO (~6 GB) downloaded to MrBot | ~5 min |
| ISO copy | Copy ISO from MrBot to SRV01 via WinRM | ~5 min |
| Prerequisites | IIS features, .NET 4.8, Visual C++ 2013, UCMA, URL Rewrite | ~10 min |
| Schema prep | `Setup.exe /PrepareSchema` — modifies AD schema | ~5 min |
| AD prep | `Setup.exe /PrepareAD` — prepares AD organization | ~3 min |
| Exchange install | `Setup.exe /Mode:Install /Role:Mailbox` | ~20-45 min |
| Mailbox creation | Create mailboxes for all domain users | ~5 min |
| DNS config | Configure internal DNS adapter | ~1 min |
| Mail bot | Deploy mail reader bot with scheduled task | ~1 min |

### 7.4 New Users Added

| Username | Password | Domain | Group |
|----------|----------|--------|-------|
| `lysa.arryn` | `rob1nIsMyHeart` | sevenkingdoms.local | Arryn |
| `robin.arryn` | `mommy` | sevenkingdoms.local | Arryn |

### 7.5 Accessing Exchange

After deployment, Exchange OWA is available at:

```
https://192.168.10.21/owa
```

Access via SSH tunnel: `ssh -L 8443:192.168.10.21:443 mrbot` then browse to `https://localhost:8443/owa`

RDP to SRV01: `ssh -L 3395:192.168.10.21:3389 mrbot` then RDP to `localhost:3395`

---

## Troubleshooting Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `403 Permission check failed` on Packer/Terraform | Missing privilege on `GoadInfraRole` | Add the missing privilege via `pveum role modify GoadInfraRole -privs "..."` |
| `storage 'local' does not support vm images` | `images` not in storage content types | `pvesm set local --content import,backup,vztmpl,iso,images` |
| QEMU exit code 1 on VM start | `vlan_tag` on a portless bridge | Remove `vlan_tag` from Packer/Terraform configs |
| Packer stuck "Waiting for WinRM" | No DHCP on vmbr3 (APIPA addresses) | Install dnsmasq on PVE for vmbr3 |
| Packer stuck "Waiting for WinRM" (with DHCP) | Missing `VM.GuestAgent.*` privileges | Add `VM.GuestAgent.Audit` and `VM.GuestAgent.Unrestricted` to role |
| "Windows could not complete the installation" | Invalid `<Order>0</Order>` in Autounattend | FirstLogonCommands Order must start at 1, not 0 |
| Packer script "not recognized as cmdlet" | Elevated command wrapper fails on Proxmox | Remove `elevated_user`/`elevated_password` from provisioners |
| `ModuleNotFoundError: No module named 'azure'` | GOAD imports all providers at startup | `pip install azure-identity azure-mgmt-compute azure-mgmt-network boto3` |
| Ansible UNREACHABLE on first run | VMs still booting after clone | Wait for GOAD's automatic retry, or re-run manually |
| Root partition filling up | VM disks on `local` (small root partition) | Move templates to `local-lvm` with `qm move-disk`, update `pm_storage` |
| Ansible process silently dies | WinRM timeout during long Windows feature install (e.g., IIS, MSSQL) | Resume with `-a true` flag (ansible-only, skips Terraform). Use `stdbuf -oL tee` for line-buffered output |
| No real-time output in tmux | `tee` buffers output by default when stdout is not a terminal | Prefix with `stdbuf -oL`: `python3 goad.py ... 2>&1 \| stdbuf -oL tee -a logfile` |
| `getpass` blocks in tmux/non-interactive | `pm_pass` not set in `goad.ini` | Add `pm_pass = password` to `[proxmox]` section and set `export TF_VAR_pm_password=password` |
| `-a` flag without `-i` fails | Instance must be selected for ansible-only mode | Add `-i <instance-id>` (e.g., `-i 18b7fb-goad-proxmox`). Find ID with `python3 goad.py -t check` |

### Useful Diagnostic Commands

```bash
# Check VM IP via guest agent (from pve2)
qm guest cmd <vmid> network-get-interfaces

# Capture VM console screenshot for debugging (from pve2)
pvesh create /nodes/pve2/qemu/<vmid>/monitor --command 'screendump /tmp/vm_screen.ppm'
scp root@pve2:/tmp/vm_screen.ppm . && sips -s format png vm_screen.ppm --out vm_screen.png

# Check Windows Firewall from PVE via guest agent
qm guest exec <vmid> -- powershell -Command "Get-NetFirewallRule | Where-Object { \$_.DisplayName -like '*WinRM*' }"

# Check network profile (Public vs Domain)
qm guest exec <vmid> -- powershell -Command "Get-NetConnectionProfile"

# Enable verbose Packer logging
PACKER_LOG=1 packer build -var-file=<vars>.pkvars.hcl .

# Test WinRM from MrBot
python3 -c "import winrm; s=winrm.Session('https://192.168.10.10:5986/wsman', auth=('vagrant','vagrant'), transport='ssl', server_cert_validation='ignore'); print(s.run_cmd('hostname'))"

# Check GOAD deploy status
ssh mrbot 'pgrep -f "ansible-playbook\|goad.py" && echo "Running" || echo "Stopped"'

# Check which Ansible playbook is running
ssh mrbot 'grep "Running command" ~/.goad/deploy2.log | tail -1'

# Resume Ansible after crash (skip Terraform, reuse existing instance)
ssh mrbot 'cd ~/GOAD && source .venv/bin/activate && export TF_VAR_pm_password=password && python3 goad.py -t install -l GOAD -p proxmox -m local -a true -i 18b7fb-goad-proxmox 2>&1 | stdbuf -oL tee -a ~/.goad/deploy2.log'

# Verify AD domains from MrBot
ssh mrbot 'cd ~/GOAD && source .venv/bin/activate && ansible -i ad/GOAD/data/inventory -i workspace/18b7fb-goad-proxmox/inventory -i globalsettings.ini dc01 -m win_shell -a "Get-ADForest | Select-Object -ExpandProperty Domains"'

# Check GOAD instance status
ssh mrbot 'cd ~/GOAD && source .venv/bin/activate && python3 goad.py -t check -l GOAD -p proxmox -m local -i 18b7fb-goad-proxmox'
```
