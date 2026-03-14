<div align="center">
  <h1><img alt="GOAD (Game Of Active Directory)" src="./docs/mkdocs/docs/img/logo_GOAD3.png"></h1>
  <br>
</div>

# GOAD — Proxmox Edition

> **Based on:** [Orange-Cyberdefense/GOAD](https://github.com/Orange-Cyberdefense/GOAD) (v3) by [@Mayfly277](https://github.com/Mayfly277)
>
> This fork patches 26 issues encountered when deploying GOAD Full on Proxmox VE and provides a complete zero-to-hero deployment guide. All fixes are documented in the [Deployment Log](docs/deployment/GOAD-DEPLOYMENT-LOG.md).

## What is GOAD?

GOAD (Game of Active Directory) is a vulnerable Active Directory lab for practising pentesting techniques. It deploys a full Windows AD environment with intentional misconfigurations, vulnerable services, and multiple attack paths.

> [!CAUTION]
> This lab is extremely vulnerable. Do not deploy it on an internet-facing network without proper isolation. This is a pentesting practice environment — use at your own risk.

### What You Get

The GOAD Full lab deploys **5 Windows VMs** across **2 AD forests** and **3 domains**:

<div align="center">
<img alt="GOAD" width="800" src="./docs/img/GOAD_schema.png">
</div>

| VM | Hostname | Domain | OS | Role |
|----|----------|--------|----|------|
| DC01 | kingslanding | sevenkingdoms.local | Server 2019 | Root domain DC |
| DC02 | winterfell | north.sevenkingdoms.local | Server 2019 | Child domain DC |
| DC03 | meereen | essos.local | Server 2016 | External forest DC + ADCS |
| SRV02 | castelblack | north.sevenkingdoms.local | Server 2019 | MSSQL + IIS + SSMS |
| SRV03 | braavos | essos.local | Server 2016 | MSSQL + ADCS |

**Attack surfaces included:** Kerberoasting, AS-REP Roasting, ADCS ESC1-ESC13, MSSQL linked servers with impersonation, unconstrained delegation, LAPS, ACL abuse paths, cross-forest trust attacks, GPO abuse, and more.

---

## Prerequisites

Before starting, you need the following infrastructure in place.

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| CPU cores (for GOAD VMs) | 10 | 12+ |
| RAM (for GOAD VMs) | 20 GB | 24+ GB |
| Disk (for templates + VMs) | 200 GB | 300+ GB |

> **Note:** These are the resources consumed by the 5 GOAD VMs only. Your Proxmox host and provisioning VM need resources on top of this.

### Infrastructure You Must Have

| Component | Purpose | Details |
|-----------|---------|---------|
| **Proxmox VE host** | Hypervisor | A working PVE node with enough resources (see above). Root SSH access required. |
| **Provisioning VM** | Runs Packer, Terraform, Ansible | A Linux VM (Ubuntu 22.04/24.04 recommended) running on your PVE cluster with at least 2 cores, 4 GB RAM, and 20 GB disk. This is where all deployment tooling runs. |
| **Network connectivity** | Provisioning VM must reach PVE API and GOAD VMs | The provisioning VM needs access to the PVE API (port 8006) and the GOAD VM network (see network setup below). |

> [!IMPORTANT]
> **The provisioning VM is not created by GOAD.** You must set it up yourself. It needs Ubuntu (22.04 or 24.04), SSH access, and network connectivity to your PVE node. All GOAD tooling (Packer, Terraform, Ansible) runs from this VM. Throughout this guide it is referred to as the "provisioning VM".

### Windows ISOs

You need these ISOs uploaded to your PVE node's `local` ISO storage (`/var/lib/vz/template/iso/`):

| ISO | Where to Get It |
|-----|----------------|
| Windows Server 2019 Evaluation | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2019) |
| Windows Server 2016 Evaluation | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2016) |
| VirtIO drivers (`virtio-win.iso`) | [Fedora VirtIO page](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso) |

> **Licence note:** Windows evaluation ISOs are free for 180 days. After expiry, either enter a licence key or rebuild the lab.

---

## Quick Start (Zero to Hero)

This is the complete deployment flow. Each phase links to detailed instructions in the [Deployment Log](docs/deployment/GOAD-DEPLOYMENT-LOG.md).

### Phase 0: Network and SSH Setup

**Goal:** Establish connectivity between your workstation, PVE node, and provisioning VM.

**0.1 — Create an isolated bridge on PVE**

GOAD VMs run on an isolated network. Create a bridge with NAT on your PVE node:

```bash
# On PVE node — append to /etc/network/interfaces:
auto vmbr3
iface vmbr3 inet static
    address 192.168.10.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up   echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up   iptables -t nat -A POSTROUTING -s '192.168.10.0/24' -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s '192.168.10.0/24' -o vmbr0 -j MASQUERADE
```

Apply with `ifreload -a`. Replace `192.168.10.0/24` with your preferred GOAD subnet if needed.

> **Why vmbr3?** The Packer HCL files hardcode `vmbr3` as the network bridge. Using this name avoids modifying upstream source files.

**0.2 — Install DHCP on PVE for the GOAD network**

Windows VMs need DHCP during Packer template builds:

```bash
# On PVE node:
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

**0.3 — Connect provisioning VM to the GOAD network**

Add a second NIC to your provisioning VM on `vmbr3`:

```bash
# On PVE node (replace <VMID> with your provisioning VM's ID):
qm set <VMID> --net1 virtio,bridge=vmbr3,firewall=0
```

Then on the provisioning VM, bring it up:

```bash
sudo ip link set ens19 up
sudo ip addr add 192.168.10.2/24 dev ens19
```

Make it persistent (Ubuntu/netplan):

```yaml
# /etc/netplan/60-goad.yaml
network:
  version: 2
  ethernets:
    ens19:
      addresses:
        - 192.168.10.2/24
```

```bash
sudo chmod 600 /etc/netplan/60-goad.yaml
sudo netplan apply
```

**0.4 — SSH from provisioning VM to PVE**

```bash
# On provisioning VM:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
ssh-copy-id root@<PVE_IP>

# Verify:
ssh root@<PVE_IP> hostname
```

### Phase 1: PVE API User and Storage

**1.1 — Create API user and role**

```bash
# On PVE node:
pveum role add GoadInfraRole -privs "Datastore.AllocateSpace,Datastore.AllocateTemplate,Datastore.Audit,Pool.Allocate,Pool.Audit,SDN.Use,Sys.Audit,VM.Allocate,VM.Audit,VM.Clone,VM.Config.CDROM,VM.Config.CPU,VM.Config.Cloudinit,VM.Config.Disk,VM.Config.HWType,VM.Config.Memory,VM.Config.Network,VM.Config.Options,VM.Console,VM.Migrate,VM.PowerMgmt,VM.Snapshot,VM.GuestAgent.Audit,VM.GuestAgent.Unrestricted"

pveum user add infra_as_code@pve --password "<YOUR_API_PASSWORD>"
pveum aclmod / -user infra_as_code@pve -role GoadInfraRole
```

> **Privilege notes:** The upstream docs miss several required privileges. This role includes `VM.GuestAgent.Audit` and `VM.GuestAgent.Unrestricted` (needed for Packer to discover VM IPs), `Datastore.AllocateTemplate` (needed for template conversion), and `VM.Snapshot`. The full set above has been tested and works.

**1.2 — Create resource pools**

```bash
pvesh create /pools --poolid Templates --comment "GOAD Packer templates"
pvesh create /pools --poolid GOAD --comment "GOAD lab VMs"
```

**1.3 — Enable images on local storage**

```bash
pvesm set local --content import,backup,vztmpl,iso,images
```

### Phase 2: Provisioning VM Setup

**2.1 — Install system packages**

```bash
# On provisioning VM:
sudo apt update
sudo apt install -y git vim tmux curl gnupg software-properties-common mkisofs sshpass python3-pip python3-venv python3.12-venv
```

> **Note:** The upstream `setup_proxmox.sh` script may fail if `sudo` requires a password via stdin. The manual steps above are more reliable.

**2.2 — Install Packer and Terraform**

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install -y packer terraform
```

**2.3 — Clone this repo and set up Python**

```bash
git clone https://github.com/CybergoN1/GOAD.git ~/GOAD
cd ~/GOAD
python3 -m venv .venv
source .venv/bin/activate

pip install rich psutil Jinja2 pyyaml ansible_runner pywinrm proxmoxer requests setuptools ansible-core==2.18.0
pip install azure-identity azure-mgmt-compute azure-mgmt-network boto3

# Symlink venv for goad.sh compatibility:
mkdir -p ~/.goad
ln -s ~/GOAD/.venv ~/.goad/.venv
```

> **Why Azure/AWS packages?** GOAD imports all provider modules at startup regardless of which provider you selected. Without these packages, you get `ModuleNotFoundError` even when using Proxmox only.

**2.4 — Install Ansible Galaxy collections**

```bash
ansible-galaxy collection install ansible.windows community.windows chocolatey.chocolatey ansible.posix scicore.guacamole community.mysql community.crypto community.general
```

### Phase 3: Build Packer Templates

**3.1 — Download Cloudbase-Init**

```bash
cd ~/GOAD/packer/proxmox/
wget -O scripts/sysprep/CloudbaseInitSetup_Stable_x64.msi \
  "https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
```

**3.2 — Build ISOs and configure Packer**

```bash
# Build autounattend ISOs:
./build_proxmox_iso.sh

# Copy scripts ISO to PVE:
scp iso/scripts_withcloudinit.iso root@<PVE_IP>:/var/lib/vz/template/iso/

# Create Packer config:
cp config.auto.pkrvars.hcl.template config.auto.pkrvars.hcl
```

Edit `config.auto.pkrvars.hcl`:

```hcl
proxmox_url             = "https://<PVE_IP>:8006/api2/json"
proxmox_username        = "infra_as_code@pve"
proxmox_password        = "<YOUR_API_PASSWORD>"
proxmox_skip_tls_verify = "true"
proxmox_node            = "<PVE_NODE_NAME>"
proxmox_pool            = "Templates"
proxmox_iso_storage     = "local"
proxmox_vm_storage      = "local"
```

> **Storage note:** Packer templates use `qcow2` format, which requires directory storage (`local`). The GOAD VMs are later deployed to `local-lvm` (LVM-thin) using linked clones — format conversion is automatic.

**3.3 — Initialise and build**

```bash
packer init .

# Build Server 2019 template:
packer build -var-file=windows_server2019_proxmox_cloudinit.pkvars.hcl .

# Build Server 2016 template:
packer build -var-file=windows_server2016_proxmox_cloudinit.pkvars.hcl .
```

Note the template IDs that Packer creates (visible in PVE UI or Packer output). You'll need them for the next step.

> **Troubleshooting:** If Packer hangs at "Waiting for WinRM", check: (1) dnsmasq is running on PVE, (2) `VM.GuestAgent.*` privileges are set, (3) the VM got an IP (check via `qm guest cmd <vmid> network-get-interfaces` on PVE). See the [Troubleshooting section](docs/deployment/GOAD-DEPLOYMENT-LOG.md#troubleshooting-quick-reference) for all known issues.

### Phase 4: Configure GOAD

**4.1 — Create goad.ini**

```bash
mkdir -p ~/.goad
cat > ~/.goad/goad.ini << 'EOF'
[default]
lab = GOAD
provider = proxmox
provisioner = local
ip_range = 192.168.10

[proxmox]
pm_api_url = https://<PVE_IP>:8006/api2/json
pm_user = infra_as_code@pve
pm_pass = <YOUR_API_PASSWORD>
pm_node = <PVE_NODE_NAME>
pm_pool = GOAD
pm_full_clone = false
pm_storage = local-lvm
pm_vlan = 0
pm_network_bridge = vmbr3
pm_network_model = e1000

[proxmox_templates_id]
WinServer2019_x64 = <SERVER_2019_TEMPLATE_ID>
WinServer2016_x64 = <SERVER_2016_TEMPLATE_ID>
EOF
```

Replace all `<PLACEHOLDER>` values with your environment details.

| Setting | What to Put |
|---------|-------------|
| `<PVE_IP>` | Your Proxmox node's IP address |
| `<YOUR_API_PASSWORD>` | The password you set for `infra_as_code@pve` |
| `<PVE_NODE_NAME>` | Your PVE node hostname (e.g., `pve`, `pve2`) |
| `<SERVER_2019_TEMPLATE_ID>` | VM ID of the Server 2019 Packer template |
| `<SERVER_2016_TEMPLATE_ID>` | VM ID of the Server 2016 Packer template |

> **Key settings explained:**
> - `pm_storage = local-lvm` — Deploy VM disks to LVM-thin storage (large partition), not `local` (small root partition)
> - `pm_vlan = 0` — Disables VLAN tagging. Required when vmbr3 has `bridge-ports none`
> - `pm_pass` — Required for non-interactive execution. Without it, the script prompts for a password and blocks in tmux/automation
> - `ip_range = 192.168.10` — Must match the vmbr3 subnet. VMs get IPs like .10, .11, .12, .22, .23

### Phase 5: Deploy

**5.1 — Move templates to the correct storage**

If your Packer templates were built on `local` but you want VMs on `local-lvm`, move them first:

```bash
# On PVE node (use your actual template IDs):
qm move-disk <SERVER_2019_TEMPLATE_ID> sata0 local-lvm --delete 1
qm move-disk <SERVER_2016_TEMPLATE_ID> sata0 local-lvm --delete 1
```

**5.2 — Run the deployment**

```bash
# On provisioning VM:
cd ~/GOAD
source .venv/bin/activate
export TF_VAR_pm_password='<YOUR_API_PASSWORD>'

# Run in tmux for resilience:
tmux new-session -d -s goad "cd ~/GOAD && source .venv/bin/activate && \
  export TF_VAR_pm_password='<YOUR_API_PASSWORD>' && \
  python3 goad.py -t install -l GOAD -p proxmox -m local \
  2>&1 | stdbuf -oL tee -a ~/.goad/deploy.log; exec bash"
```

The installer will prompt twice:
1. `Create lab with theses settings? (y/N)` — type `y`
2. `Enter a value:` (Terraform apply) — type `yes`

> **Tip:** Use `stdbuf -oL` with `tee` to get real-time output in tmux. Without it, output buffers and appears to hang.

**5.3 — Monitor progress**

```bash
# Attach to tmux session:
tmux attach -t goad
# Detach without killing: Ctrl+B then D

# Check which playbook is running:
grep "Running command" ~/.goad/deploy.log | tail -1

# Check if process is still alive:
pgrep -f "ansible-playbook\|goad.py"
```

**5.4 — If Ansible dies mid-run**

Long-running Windows tasks (IIS, MSSQL installs) can cause WinRM timeouts. If the process dies, resume with:

```bash
# Find your instance ID:
python3 goad.py -t check -l GOAD -p proxmox -m local

# Resume (ansible-only, skips Terraform):
python3 goad.py -t install -l GOAD -p proxmox -m local -a true -i <INSTANCE_ID> \
  2>&1 | stdbuf -oL tee -a ~/.goad/deploy.log
```

Ansible is idempotent — re-running completed playbooks is safe (they show `ok` and skip quickly).

### Phase 6: Verify

Once the installer reports `Lab successfully provisioned`, verify from the provisioning VM:

```bash
# Ping all VMs:
for ip in 192.168.10.10 192.168.10.11 192.168.10.12 192.168.10.22 192.168.10.23; do
  ping -c 1 -W 2 $ip && echo "OK" || echo "FAIL"
done

# Check GOAD status:
cd ~/GOAD && source .venv/bin/activate
python3 goad.py -t check -l GOAD -p proxmox -m local
```

**Expected state after deployment:**

| Check | Expected |
|-------|----------|
| All 5 VMs pingable | Yes |
| WinRM (port 5986) reachable | All 5 VMs |
| DNS resolves all 3 domains | sevenkingdoms.local, north.sevenkingdoms.local, essos.local |
| AD trusts | Bidirectional between sevenkingdoms.local and essos.local |
| MSSQL Express | Running on srv02 and srv03 |
| IIS | Running on srv02 |
| ADCS | Running on dc01 and srv03, with ESC1-ESC13 templates |
| LAPS | Configured on essos.local (srv03 has LAPS password) |

For the full verification checklist with commands, see [Phase 6 in the Deployment Log](docs/deployment/GOAD-DEPLOYMENT-LOG.md#phase-6-post-install-verification).

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Packer stuck "Waiting for WinRM" | No DHCP on vmbr3 | Install dnsmasq (see Phase 0.2) |
| Packer stuck "Waiting for WinRM" (DHCP working) | Missing `VM.GuestAgent.*` privileges | Add to GoadInfraRole (see Phase 1.1) |
| `403 Permission check failed` | Missing PVE privilege | Check the full privilege list in Phase 1.1 |
| QEMU exit code 1 on VM start | VLAN tag on portless bridge | Set `pm_vlan = 0` in goad.ini |
| `ModuleNotFoundError: azure` | Missing Python packages | `pip install azure-identity azure-mgmt-compute azure-mgmt-network boto3` |
| Ansible UNREACHABLE first run | VMs still booting after clone | Wait for GOAD's automatic retry |
| Ansible process dies silently | WinRM timeout during Windows installs | Resume with `-a true` flag (see Phase 5.4) |
| No tmux output | tee buffering | Use `stdbuf -oL tee` |
| `getpass` prompt blocks script | `pm_pass` not in goad.ini | Add `pm_pass = <password>` to `[proxmox]` section |
| Root partition filling up | VMs deployed to `local` | Move templates to `local-lvm`, set `pm_storage = local-lvm` |

For the complete troubleshooting reference with 15+ issues and diagnostic commands, see the [Deployment Log](docs/deployment/GOAD-DEPLOYMENT-LOG.md#troubleshooting-quick-reference).

---

## Available Labs

This fork supports the same lab variants as upstream GOAD. This guide covers **GOAD Full** on Proxmox. For other labs or providers, see the [upstream documentation](https://orange-cyberdefense.github.io/GOAD/).

<div align="center">
<img alt="GOAD" width="800" src="./docs/img/diagram-GOADv3-full.png">
</div>

- [GOAD](https://orange-cyberdefense.github.io/GOAD/labs/GOAD/) : 5 vms, 2 forests, 3 domains (full goad lab)
<div align="center">
<img alt="GOAD" width="800" src="./docs/img/GOAD_schema.png">
</div>

- [GOAD-Light](https://orange-cyberdefense.github.io/GOAD/labs/GOAD-Light/) : 3 vms, 1 forest, 2 domains (smaller goad lab for those with a smaller pc)
<div align="center">
<img alt="GOAD Light" width="600" src="./docs/img/GOAD-Light_schema.png">
</div>

- [MINILAB](https://orange-cyberdefense.github.io/GOAD/labs/MINILAB/): 2 vms, 1 forest, 1 domain (basic lab with one DC (windows server 2019) and one Workstation (windows 10))

- [SCCM](https://orange-cyberdefense.github.io/GOAD/labs/SCCM/) : 4 vms, 1 forest, 1 domain, with microsoft configuration manager installed
<div align="center">
<img alt="SCCM" width="600" src="./docs/img/SCCMLAB_overview.png">
</div>

- [NHA](https://orange-cyberdefense.github.io/GOAD/labs/NHA/) : A challenge with 5 vms and 2 domains. no schema provided, you will have to find out how break it.
<div align="center">
<img alt="NHA" width="600" src="./docs/img/logo_NHA.jpeg">
</div>

- [DRACARYS](https://orange-cyberdefense.github.io/GOAD/labs/DRACARYS/) : A challenge with 3 vms and 1 domains. no schema provided, you will have to find out how break it.
<div align="center">
<img alt="DRACARYS" width="600" src="./docs/img/dracarys_logo.png">
</div>

---

## What This Fork Fixes

This fork addresses 26 issues encountered during real-world Proxmox deployment that are not covered in the upstream documentation:

| Category | Issues Fixed |
|----------|-------------|
| PVE privileges | 5 missing/incorrect privileges |
| VLAN/network | VLAN tagging on portless bridges, missing DHCP |
| Packer on Proxmox | Elevated command wrapper, Defender interference, guest agent |
| Storage | `local` vs `local-lvm` sizing, content types |
| Python compatibility | Python 3.12, Azure/AWS imports, setuptools |
| Keyboard/locale | French default changed to US English |
| Operational | `pm_pass` config key, Ansible crash recovery |

Full details: [Changes from Plan](docs/deployment/GOAD-DEPLOYMENT-LOG.md#changes-from-plan)

---

## Credits

- **[Orange Cyberdefense](https://github.com/Orange-Cyberdefense)** — Original GOAD project
- **[@Mayfly277](https://github.com/Mayfly277)** — GOAD creator and maintainer
- **[Upstream documentation](https://orange-cyberdefense.github.io/GOAD/)** — Reference docs for all lab variants and providers

---

## Licenses

This lab uses free Windows VM only (180 days). After that delay enter a license on each server or rebuild all the lab (may be it's time for an update ;))

See the [upstream GOAD licence](https://github.com/Orange-Cyberdefense/GOAD/blob/main/LICENSE) for code licensing.
