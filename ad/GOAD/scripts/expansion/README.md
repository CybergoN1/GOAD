# GOAD User Expansion Scripts

Adds 60 users across all 3 domains, file shares, MSSQL logins, Exchange mailboxes, and BEC scenarios. Designed to give the lab realistic noise for enumeration practice.

## Running via Ansible (Recommended)

From the provisioning VM (MrBot), run each script on its target server:

```bash
cd ~/GOAD && source .venv/bin/activate

# Step 1: sevenkingdoms.local users (DC01)
ansible -i ad/GOAD/data/inventory -i workspace/<INSTANCE_ID>/inventory -i globalsettings.ini \
  dc01 -m win_copy -a "src=ad/GOAD/scripts/expansion/01-create-users-sevenkingdoms.ps1 dest=C:/setup/01-create-users-sevenkingdoms.ps1"
ansible -i ad/GOAD/data/inventory -i workspace/<INSTANCE_ID>/inventory -i globalsettings.ini \
  dc01 -m win_shell -a "powershell -ExecutionPolicy Bypass -File C:/setup/01-create-users-sevenkingdoms.ps1"

# Step 2: north.sevenkingdoms.local users (DC02)
ansible ... dc02 -m win_copy -a "src=ad/GOAD/scripts/expansion/02-create-users-north.ps1 dest=C:/setup/02-create-users-north.ps1"
ansible ... dc02 -m win_shell -a "powershell -ExecutionPolicy Bypass -File C:/setup/02-create-users-north.ps1"

# Step 3: essos.local users (DC03)
ansible ... dc03 -m win_copy -a "src=ad/GOAD/scripts/expansion/03-create-users-essos.ps1 dest=C:/setup/03-create-users-essos.ps1"
ansible ... dc03 -m win_shell -a "powershell -ExecutionPolicy Bypass -File C:/setup/03-create-users-essos.ps1"

# Step 4: Shares and MSSQL (SRV02) — run MSSQL part via sqlcmd as vagrant has sysadmin
ansible ... srv02 -m win_copy -a "src=ad/GOAD/scripts/expansion/04-setup-shares-mssql.ps1 dest=C:/setup/04-setup-shares-mssql.ps1"
ansible ... srv02 -m win_shell -a "powershell -ExecutionPolicy Bypass -File C:/setup/04-setup-shares-mssql.ps1"

# Step 5: Exchange mailboxes and BEC (SRV01) — requires domain admin
ansible ... srv01 -m win_copy -a "src=ad/GOAD/scripts/expansion/05-setup-exchange-mailboxes-bec.ps1 dest=C:/setup/05-setup-exchange-mailboxes-bec.ps1"
ansible ... srv01 -m win_shell -a "powershell -ExecutionPolicy Bypass -File C:/setup/05-setup-exchange-mailboxes-bec.ps1" \
  -e "ansible_become=true ansible_become_method=runas ansible_become_user=SEVENKINGDOMS\\cersei.lannister ansible_become_password=il0vejaime"
```

Replace `<INSTANCE_ID>` with your GOAD instance ID (e.g., `18b7fb-goad-proxmox`).

### Alternative: Single script via PowerShell Remoting

`run-all-from-dc01.ps1` runs everything from DC01 using `Invoke-Command` to reach other servers. RDP into DC01 and run it as a domain admin. Note: Exchange mailbox and BEC steps require running directly on SRV01 via Ansible (Kerberos double-hop prevents nested remoting for Exchange cmdlets).

## What Gets Created

### Users (60 total)

| Domain | OU | Users | Count |
|--------|-----|-------|-------|
| sevenkingdoms.local | Dorne | oberyn.martell, ellaria.sand, doran.martell, trystane.martell, obara.sand, nymeria.sand, tyene.sand, areo.hotah | 8 |
| sevenkingdoms.local | Reach | olenna.tyrell, margaery.tyrell, loras.tyrell, mace.tyrell, randyll.tarly, dickon.tarly, garlan.tyrell | 7 |
| sevenkingdoms.local | IronIslands | balon.greyjoy, theon.greyjoy, yara.greyjoy, euron.greyjoy, victarion.greyjoy, aeron.greyjoy | 6 |
| sevenkingdoms.local | Riverlands | edmure.tully, brynden.tully, walder.frey, lothar.frey, roslin.frey, stevron.frey, olyvar.frey | 7 |
| sevenkingdoms.local | Stormlands | davos.seaworth, gendry.baratheon, brienne.tarth, beric.dondarrion, podrick.payne, selyse.baratheon | 6 |
| north.sevenkingdoms.local | Wildlings | tormund.giantsbane, mance.rayder, ygritte, craster, styr | 5 |
| north.sevenkingdoms.local | Bolton | roose.bolton, ramsay.bolton, locke | 3 |
| north.sevenkingdoms.local | Manderly | wyman.manderly, wylis.manderly | 2 |
| north.sevenkingdoms.local | CN=Users | meera.reed, jojen.reed, benjen.stark, lyanna.mormont | 4 |
| essos.local | Meereen | grey.worm, daario.naharis, hizdahr.loraq, barristan.selmy, tyrion.essos | 5 |
| essos.local | Pentos | illyrio.mopatis, varys.essos | 2 |
| essos.local | Braavos | syrio.forel, jaqen.hghar, tycho.nestoris, izembaro | 4 |
| essos.local | Volantis | kinvara | 1 |

### Attack Surface Added

- **8 Kerberoastable accounts** (SPNs set): loras.tyrell, theon.greyjoy, brienne.tarth, davos.seaworth, tormund.giantsbane, roose.bolton, tycho.nestoris, daario.naharis
- **8 AS-REP Roastable accounts** (no preauth): trystane.martell, podrick.payne, olyvar.frey, dickon.tarly, craster, ramsay.bolton, izembaro, hizdahr.loraq
- **6 BEC scenarios** (see below)
- **6 file shares** with realistic loot documents
- **8 MSSQL domain logins** including 1 over-privileged sysadmin (brienne.tarth) and impersonation chain (theon -> walder)
- **1 weak SQL auth login** (`finance_reports` / `reports2024`)
- **6 seed emails** in mailboxes for forensic investigation

### File Shares (on SRV02 / castelblack)

| Share | Full Access | Loot |
|-------|------------|------|
| `\\castelblack\Dorne` | Martell group | Trade routes with contact emails |
| `\\castelblack\IronIslands` | Greyjoy group | Fleet manifest with dock codes |
| `\\castelblack\Reach` | Tyrell group | Harvest report |
| `\\castelblack\Riverlands` | Tully + Frey groups | Bridge toll records |
| `\\castelblack\Finance` | Small Council | Budget, vendor payments, wire transfer template |
| `\\castelblack\HR` | Small Council | New starter list with default password policy, salary bands |

### BEC Scenarios

| # | Technique | Victim | Attacker | Detection |
|---|-----------|--------|----------|-----------|
| 1 | Internal mail forwarding | doran.martell | ellaria.sand | `Get-Mailbox doran.martell \| FL ForwardingAddress` |
| 2 | Hidden inbox rule (finance keywords) | olenna.tyrell | walder.frey | `Get-InboxRule -Mailbox olenna.tyrell` |
| 3 | Full mail redirect (altRecipient) | mace.tyrell | margaery.tyrell | `Get-Mailbox mace.tyrell \| FL ForwardingAddress,DeliverToMailboxAndForward` |
| 4 | External SMTP forwarding | walder.frey | external-twins.com | `Get-Mailbox walder.frey \| FL ForwardingSMTPAddress` |
| 5 | Hidden mailbox delegation | balon.greyjoy | euron.greyjoy | `Get-MailboxPermission balon.greyjoy \| Where {$_.User -ne "NT AUTHORITY\SELF"}` |
| 6 | Send-As via FullAccess | balon.greyjoy | euron.greyjoy | Same as above (AutoMapping disabled) |

### Exchange Mailbox Limitations

Exchange is installed in `sevenkingdoms.local` only. Mailboxes can only be created for users in that domain. Users in `north.sevenkingdoms.local` and `essos.local` do not get Exchange mailboxes (this is by design — Exchange schema prep was only done for the root domain).
