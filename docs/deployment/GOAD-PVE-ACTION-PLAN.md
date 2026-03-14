# GOAD Full Lab - PVE2 Deployment Action Plan

> This document lists every action that will be taken on your Proxmox node (pve2)
> and provisioning VM (MrBot) to deploy the full GOAD lab. Nothing outside of
> what is listed here will be modified.
>
> **Reviewed by:** Pedantic Fact Checker agent, Process Enforcer agent
> **Verdict:** All critical/major issues resolved in this revision.

## Current Environment (unchanged)

| Item | Detail |
|------|--------|
| Cluster nodes | pve, pve2, pve3 |
| Target node | **pve2** (192.168.3.213) |
| Provisioning VM | **MrBot** (VM 110, 192.168.3.106, Ubuntu 24.04) - already set up |
| Existing VMs | 100-115 across cluster - **not touched** |
| Existing network | vmbr0 (192.168.3.0/24) - **not touched** |
| Existing storage | local, local-lvm, terabyte - **not touched** |
| Existing users | current users - **not touched** |

## Resource Budget

| Resource | Available | GOAD Requires | Remaining After |
|----------|-----------|---------------|-----------------|
| CPU cores | 20 (12 free) | 10 cores | 2 free |
| RAM | 32 GB (22 GB free) | ~20.2 GB | ~1.8 GB |
| Disk (local-lvm) | ~816 GB free | ~200 GB | ~616 GB |

> **WARNING:** RAM is tight. Full GOAD needs ~20.2 GB (DC01: 3096 MB, DC02: 3096 MB,
> SRV02: 6240 MB, DC03: 3096 MB, SRV03: 5120 MB = 20,648 MB) and you have ~22 GB free.
> Consider stopping some existing VMs when running the lab.
> Alternatively, GOAD-Light (3 VMs, ~9 GB) is a safer option.

---

## Phase 0: Prerequisites

### Action 0.1 - Ensure MrBot can SSH to pve2

**What:** MrBot needs root SSH access to pve2 to copy ISOs via SCP.
**Where:** MrBot and pve2
**Impact:** Adds MrBot's public key to pve2's authorized_keys.

```bash
# On MrBot: generate a key if one doesn't exist
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "mrbot-to-pve2"

# Copy the key to pve2 (will prompt for root password)
ssh-copy-id root@192.168.3.213

# Verify
ssh root@192.168.3.213 hostname
```

---

## Phase 1: PVE Node Configuration

### Action 1.1 - Create API user and role

**What:** Create a dedicated Proxmox user for Terraform/Packer API access.
**Where:** pve2 shell (via SSH)
**Impact:** Adds a new user and role. No existing users or permissions affected.

```bash
# Create the role with required permissions
pveum role add GoadInfraRole -privs "Sys.Audit VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CloudInit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt VM.Audit Datastore.AllocateSpace Datastore.Audit Pool.Allocate Pool.Audit SDN.Use"

# Create the user
pveum user add infra_as_code@pve --password <you-choose-a-password>

# Assign the role to the user at the root level
pveum aclmod / -user infra_as_code@pve -role GoadInfraRole
```

> **Note:** `Sys.Audit` is included as the bpg/proxmox Terraform provider may
> require it for node operations.

### Action 1.2 - Create resource pools

**What:** Create two pools to organize GOAD VMs separately from your existing VMs.
**Where:** pve2 shell
**Impact:** New pools only. Existing VMs are not assigned to any pool and are unaffected.

```bash
pvesh create /pools --poolid Templates --comment "GOAD Packer templates"
pvesh create /pools --poolid GOAD --comment "GOAD lab VMs"
```

### Action 1.3 - Create isolated network bridge

**What:** Create a new virtual bridge (`vmbr3`) for the GOAD AD network.
**Where:** pve2 network config (`/etc/network/interfaces`)
**Impact:** Adds a new bridge. vmbr0 and your existing network are untouched.
This bridge has NO physical interface - it's internal-only for VM-to-VM traffic.

> **Why `vmbr3` and not `vmbr1`?** The Packer HCL config (`packer.json.pkr.hcl`)
> has `bridge = "vmbr3"` and `vlan_tag = "10"` hardcoded. Using `vmbr3` avoids
> having to modify Packer source files.

```bash
# Append to /etc/network/interfaces:
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

# Then reload networking
ifreload -a
```

**Notes:**
- IP range `192.168.10.0/24` is used for GOAD VMs (avoids conflict with your 192.168.3.0/24)
- The NAT/masquerade rules let GOAD VMs reach the internet (needed for Ansible provisioning)
- After provisioning, NAT can be removed to fully isolate the lab

### Action 1.4 - Add static route on MrBot

**What:** MrBot (192.168.3.106) needs to reach GOAD VMs on 192.168.10.0/24 for
Ansible provisioning via WinRM. pve2 can route between the two networks since it
has interfaces on both vmbr0 (192.168.3.x) and vmbr3 (192.168.10.x).
**Where:** MrBot
**Impact:** Adds a route. No other networking changes.

```bash
# Add route now
sudo ip route add 192.168.10.0/24 via 192.168.3.213

# Make persistent (Ubuntu 24.04 uses netplan)
# Add to /etc/netplan/ config:
#   routes:
#     - to: 192.168.10.0/24
#       via: 192.168.3.213
```

**Verify:**
```bash
ping -c 1 192.168.10.1   # Should reach pve2's vmbr3 interface
```

---

## Phase 2: Upload ISOs to PVE

### Action 2.1 - Download Windows evaluation ISOs

**What:** Download 2 Windows eval ISOs + VirtIO drivers to PVE ISO storage.
**Where:** pve2 `/var/lib/vz/template/iso/`
**Impact:** ~12 GB of files added to local storage. Nothing else modified.

> **Note:** Windows 10 ISO is NOT needed for GOAD Full. It is only required for
> the optional `ws01` extension. Only Server 2019 and Server 2016 are needed.

| ISO | Size | Filename |
|-----|------|----------|
| Windows Server 2019 | ~5 GB | `windows_server2019_x64FREE_en-us.iso` |
| Windows Server 2016 | ~6 GB | `windows_server_2016_14393.0_eval_x64.iso` |
| VirtIO drivers | ~600 MB | `virtio-win.iso` |

```bash
cd /var/lib/vz/template/iso/

# Windows Server 2019
wget -O windows_server2019_x64FREE_en-us.iso \
  "https://software-static.download.prss.microsoft.com/dbazure/988969d5-f34g-4e03-ac9d-1f9786c66749/17763.3650.221105-1748.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us.iso"

# Windows Server 2016
wget -O windows_server_2016_14393.0_eval_x64.iso \
  "https://software-download.microsoft.com/download/pr/Windows_Server_2016_Datacenter_EVAL_en-us_14393_refresh.ISO"

# VirtIO drivers
wget -O virtio-win.iso \
  "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
```

> **If download URLs fail:** Microsoft evaluation ISO URLs change periodically.
> Get current links from https://www.microsoft.com/en-us/evalcenter/

### Action 2.2 - Download Cloudbase-Init

**What:** Download Cloudbase-Init MSI to MrBot (used by Packer during template build).
**Where:** MrBot `~/GOAD/packer/proxmox/scripts/sysprep/`
**Impact:** Single 55 MB file downloaded.

```bash
# On MrBot:
wget -O ~/GOAD/packer/proxmox/scripts/sysprep/CloudbaseInitSetup_Stable_x64.msi \
  "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
```

---

## Phase 3: Build Packer Templates (on MrBot)

### Action 3.1 - Build Packer ISOs

**What:** Create the provisioning ISOs that Packer mounts during Windows template builds.
The script produces **7 ISOs**: 6 Autounattend ISOs (used locally by Packer for
unattended Windows installs) + `scripts_withcloudinit.iso` (uploaded to PVE).
It also updates checksum values in the `.pkvars.hcl` files.
**Where:** MrBot `~/GOAD/packer/proxmox/`
**Impact:** ISO files created locally. One ISO uploaded to PVE.

```bash
# On MrBot:
cd ~/GOAD/packer/proxmox/
./build_proxmox_iso.sh

# Copy the scripts ISO to PVE (requires SSH from Action 0.1)
scp iso/scripts_withcloudinit.iso root@192.168.3.213:/var/lib/vz/template/iso/
```

### Action 3.2 - Configure Packer

**What:** Set Packer variables to point at your PVE node.
**Where:** MrBot `~/GOAD/packer/proxmox/config.auto.pkrvars.hcl`
**Impact:** Config file creation only.

```bash
cd ~/GOAD/packer/proxmox/
cp config.auto.pkrvars.hcl.template config.auto.pkrvars.hcl
```

Edit `config.auto.pkrvars.hcl`:

```hcl
proxmox_url             = "https://192.168.3.213:8006/api2/json"
proxmox_username        = "infra_as_code@pve"
proxmox_password        = "<password-from-action-1.1>"
proxmox_skip_tls_verify = "true"
proxmox_node            = "pve2"
proxmox_pool            = "Templates"
proxmox_iso_storage     = "local"
proxmox_vm_storage      = "local"
```

> **IMPORTANT: `proxmox_vm_storage` must be `local` (not `local-lvm`).**
> The Packer variable files use `vm_disk_format = "qcow2"`, and LVM-thin storage
> (`local-lvm`) only supports `raw` format. The `local` directory storage supports
> qcow2. GOAD's Terraform will later deploy lab VMs to `local-lvm` using linked
> clones, which handles format conversion automatically.

### Action 3.3 - Change Packer disk format to raw (alternative to using `local` storage)

> **Skip this action if you used `proxmox_vm_storage = "local"` in Action 3.2.**
> Only needed if you want templates on `local-lvm` instead.

If you prefer templates on `local-lvm`, change disk format in the pkvars files:

```bash
cd ~/GOAD/packer/proxmox/
sed -i 's/vm_disk_format = "qcow2"/vm_disk_format = "raw"/' \
  windows_server2019_proxmox_cloudinit.pkvars.hcl \
  windows_server2016_proxmox_cloudinit.pkvars.hcl
```

### Action 3.4 - Build Windows templates

**What:** Packer creates 2 VM templates on PVE from the Windows ISOs.
**Where:** Runs on MrBot, creates VMs on pve2
**Impact:** Creates 2 template VMs in the `Templates` pool. ~40 GB disk each.

> **IMPORTANT:** After each build, note the **VM ID** from the Packer output
> (e.g., "template_id: 200") or check the PVE web UI under the Templates pool.
> You will need these IDs for Phase 4.

| Template | Clone Source | Disk | Build Time |
|----------|-------------|------|------------|
| WinServer2019x64-cloudinit-qcow2 | windows_server2019_x64FREE_en-us.iso | 40 GB | ~30-45 min |
| WinServer2016x64-cloudinit-qcow2 | windows_server_2016_14393.0_eval_x64.iso | 40 GB | ~30-45 min |

```bash
cd ~/GOAD/packer/proxmox/

# Initialize Packer plugins (only needed once)
packer init .

# Build Windows Server 2019 template
# >>> NOTE THE VM ID IN THE OUTPUT <<<
packer build -var-file=windows_server2019_proxmox_cloudinit.pkvars.hcl .

# Build Windows Server 2016 template
# >>> NOTE THE VM ID IN THE OUTPUT <<<
packer build -var-file=windows_server2016_proxmox_cloudinit.pkvars.hcl .
```

> Packer does NOT need the Python venv. It is a standalone binary.
> Do not `source .venv/bin/activate` for Packer commands.

---

## Phase 4: Configure GOAD (on MrBot)

### Action 4.1 - Edit globalsettings.ini

**What:** The global settings file controls keyboard layout and DNS forwarder
for all GOAD VMs. The default keyboard layout is **French** — you likely want
to change this to English.
**Where:** MrBot `~/GOAD/globalsettings.ini`
**Impact:** Config file edit only.

```ini
; Change keyboard to US English only (default is French + US)
keyboard_layouts=["00000409"]

; DNS forwarder used by domain controllers (default: 1.1.1.1)
; Change if your network blocks external DNS
dns_server_forwarder=1.1.1.1
```

### Action 4.2 - Create goad.ini

**What:** Configure GOAD to point at your PVE node with the template IDs from
the Packer builds in Action 3.4.
**Where:** MrBot `~/.goad/goad.ini`
**Impact:** Config file only.

```bash
mkdir -p ~/.goad
```

Create `~/.goad/goad.ini`:

```ini
[default]
lab = GOAD
provider = proxmox
provisioner = local
ip_range = 192.168.10

[proxmox]
pm_api_url = https://192.168.3.213:8006/api2/json
pm_user = infra_as_code@pve
pm_pass = <password-from-action-1.1>
pm_node = pve2
pm_pool = GOAD
pm_full_clone = false
pm_storage = local-lvm
pm_vlan = 10
pm_network_bridge = vmbr3
pm_network_model = e1000

[proxmox_templates_id]
winserver2019_x64 = <INTEGER VM ID from Action 3.4 packer output>
winserver2016_x64 = <INTEGER VM ID from Action 3.4 packer output>
```

> **Key details:**
> - Config key is `pm_pass` (NOT `pm_password`) — the Python code reads this key.
> - Template IDs must be **integers** (e.g., `200`, `201`).
> - `pm_vlan = 10` matches the VLAN tag hardcoded in Packer's network config.
> - `pm_network_bridge = vmbr3` matches the bridge created in Action 1.3.
> - Terraform will **also prompt for the password** during plan/apply. You can
>   avoid this by exporting: `export TF_VAR_pm_password=<password>`

---

## Phase 5: Deploy GOAD (on MrBot)

### Action 5.1 - Set Terraform password environment variable

```bash
cd ~/GOAD
source .venv/bin/activate
export TF_VAR_pm_password="<password-from-action-1.1>"
```

### Action 5.2 - Check prerequisites

```bash
./goad.sh -t check -l GOAD -p proxmox
```

### Action 5.3 - Install (Terraform + Ansible)

**What:** Terraform clones templates into 5 VMs, Ansible configures Active Directory.
**Where:** Runs on MrBot, creates VMs on pve2
**Impact:** Creates 5 VMs in the `GOAD` pool on pve2. Takes 1-2 hours.

```bash
./goad.sh -t install -l GOAD -p proxmox
```

**VMs that will be created:**

| VM Name | Hostname | Domain | IP | Cores | RAM (MB) | Template |
|---------|----------|--------|----|-------|----------|----------|
| DC01 | kingslanding | sevenkingdoms.local | 192.168.10.10 | 2 | 3096 | WinServer2019 |
| DC02 | winterfell | north.sevenkingdoms.local | 192.168.10.11 | 2 | 3096 | WinServer2019 |
| SRV02 | castelblack | north.sevenkingdoms.local | 192.168.10.22 | 2 | 6240 | WinServer2019 |
| DC03 | meereen | essos.local | 192.168.10.12 | 2 | 3096 | WinServer2016 |
| SRV03 | braavos | essos.local | 192.168.10.23 | 2 | 5120 | WinServer2016 |

**AD topology created by Ansible:**

```
Forest: sevenkingdoms.local            Forest: essos.local
├── Domain: sevenkingdoms.local        └── Domain: essos.local
│   └── DC01 (kingslanding)                ├── DC03 (meereen)
│       - ADCS                             └── SRV03 (braavos)
├── Domain: north.sevenkingdoms.local          - MSSQL
│   ├── DC02 (winterfell)                      - ADCS
│   └── SRV02 (castelblack)
│       - IIS, MSSQL, WebDAV
└── Trust ←──────────────────────────────→ Trust
```

**DNS resolution chain:**
- During initial setup, VMs use `192.168.10.1` (pve2's vmbr3) as DNS
- Domain controllers are configured first, then other VMs use DCs for DNS
- DCs use `1.1.1.1` as their external forwarder (configurable in `globalsettings.ini`)
- External DNS works via NAT masquerade on vmbr3

---

## Phase 6: Post-Install & Access

### Action 6.1 - Verify deployment

```bash
cd ~/GOAD
source .venv/bin/activate
./goad.sh -t status -l GOAD -p proxmox
```

### Action 6.2 - Access the lab

**RDP access:** Connect from any machine that can route to 192.168.10.x
(MrBot can, after the static route in Action 1.4).

**Default credentials:**

| Account | Username | Password |
|---------|----------|----------|
| Local admin (all VMs) | vagrant | vagrant |
| sevenkingdoms.local admin | SEVENKINGDOMS\Administrator | (see ad/GOAD/data/config.json) |
| north.sevenkingdoms.local admin | NORTH\Administrator | (see ad/GOAD/data/config.json) |
| essos.local admin | ESSOS\Administrator | (see ad/GOAD/data/config.json) |

### Action 6.3 - Lab lifecycle commands

```bash
# Stop all GOAD VMs
./goad.sh -t stop -l GOAD -p proxmox

# Start all GOAD VMs
./goad.sh -t start -l GOAD -p proxmox

# Destroy the lab (removes all 5 VMs)
./goad.sh -t destroy -l GOAD -p proxmox

# Re-run only Ansible provisioning (skip Terraform)
./goad.sh -t install -l GOAD -p proxmox -a
```

---

## Summary of All Changes

### On PVE2 (192.168.3.213)

| Change | Type | Reversible |
|--------|------|------------|
| Add user `infra_as_code@pve` | User/auth | `pveum user delete infra_as_code@pve` |
| Add role `GoadInfraRole` | User/auth | `pveum role delete GoadInfraRole` |
| Add pool `Templates` | Resource pool | `pvesh delete /pools/Templates` |
| Add pool `GOAD` | Resource pool | `pvesh delete /pools/GOAD` |
| Add bridge `vmbr3` | Network | Remove from `/etc/network/interfaces` |
| Upload 3 ISOs (~12 GB) | Files | Delete from `/var/lib/vz/template/iso/` |
| Upload scripts ISO | Files | Delete from `/var/lib/vz/template/iso/` |
| 2 template VMs (~80 GB) | VMs in Templates pool | `qm destroy <vmid>` |
| 5 lab VMs (~200 GB) | VMs in GOAD pool | `./goad.sh -t destroy -l GOAD -p proxmox` |

### On MrBot (192.168.3.106)

| Change | Type | Reversible |
|--------|------|------------|
| GOAD repo cloned to ~/GOAD | Files | `rm -rf ~/GOAD` |
| Python venv with deps | Files | `rm -rf ~/GOAD/.venv` |
| Packer + Terraform installed | APT packages | `apt remove packer terraform` |
| Ansible Galaxy collections | Files | `rm -rf ~/.ansible` |
| Packer config file | Files | Already created |
| goad.ini | Config file | `rm -rf ~/.goad` |
| Static route to 192.168.10.0/24 | Network | `sudo ip route del 192.168.10.0/24` |
| SSH key to pve2 | Auth | Remove from pve2 `authorized_keys` |

### Nothing Changes

- Existing VMs (100-115) on pve, pve2, pve3
- vmbr0 network and 192.168.3.0/24 subnet
- Storage layout (local, local-lvm, terabyte)
- PVE cluster configuration
- Existing users and permissions
- Any services running on existing VMs
