# GOAD Lab Credentials Reference

Complete credential reference for the GOAD pentesting lab. All passwords are intentionally weak — this is a vulnerable lab.

---

## Infrastructure Accounts

| Account | Password | Purpose |
|---------|----------|---------|
| `vagrant` | `vagrant` | Local admin on all VMs. Works even if AD is down. |
| `SEVENKINGDOMS\Administrator` | `8dCT-DJjgScp` | Built-in domain admin + Exchange Organization Management |
| `NORTH\Administrator` | `NgtI75cKV+Pu` | Built-in domain admin (north) |
| `ESSOS\Administrator` | `Ufe-bVXSx9rk` | Built-in domain admin (essos) |
| `infra_as_code@pve` | *(your API password)* | Proxmox API user for Terraform/Packer |

---

## Domain Admins

| Domain | Username | Password | Groups | Servers |
|--------|----------|----------|--------|---------|
| sevenkingdoms.local | `SEVENKINGDOMS\cersei.lannister` | `il0vejaime` | Domain Admins, Lannister, Baratheon, Small Council | All sevenkingdoms VMs |
| sevenkingdoms.local | `SEVENKINGDOMS\robert.baratheon` | `iamthekingoftheworld` | Domain Admins, Baratheon, Small Council, Protected Users | All sevenkingdoms VMs |
| north.sevenkingdoms.local | `NORTH\eddard.stark` | `FightP3aceAndHonor!` | Domain Admins, Stark | All north VMs |
| essos.local | `ESSOS\daenerys.targaryen` | `BurnThemAll!` | Domain Admins, Targaryen | All essos VMs |

---

## Exchange Admin

| Username | Password | Role | Server |
|----------|----------|------|--------|
| `SEVENKINGDOMS\lysa.arryn` | `rob1nIsMyHeart` | Organization Management, local admin on SRV01 | the-eyrie (192.168.10.21) |

**Exchange OWA:** `https://192.168.10.21/owa` (access via SSH tunnel: `ssh -L 8443:192.168.10.21:443 mrbot`)

---

## Service Accounts

| Domain | Username | Password | Service | Server | SPN (Kerberoastable) |
|--------|----------|----------|---------|--------|---------------------|
| north | `NORTH\sql_svc` | `YouWillNotKerboroast1ngMeeeeee` | MSSQL | castelblack (SRV02) | `MSSQLSvc/castelblack.north.sevenkingdoms.local:1433` |
| essos | `ESSOS\sql_svc` | `YouWillNotKerboroast1ngMeeeeee` | MSSQL | braavos (SRV03) | `MSSQLSvc/braavos.essos.local:1433` |
| — | `finance_reports` (SQL auth) | `reports2024` | MSSQL | castelblack (SRV02) | — |

---

## sevenkingdoms.local — All Users

### OU=Crownlands

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `tywin.lannister` | `powerkingftw135` | Lannister | Can force-change jaime's password (ACL) |
| `jaime.lannister` | `cersei` | Lannister | GenericWrite on joffrey (ACL) |
| `cersei.lannister` | `il0vejaime` | Lannister, Baratheon, **Domain Admins**, Small Council | Domain Admin |
| `robert.baratheon` | `iamthekingoftheworld` | Baratheon, **Domain Admins**, Small Council, **Protected Users** | Domain Admin, Protected Users |
| `joffrey.baratheon` | `1killerlion` | Baratheon, Lannister | WriteDacl on tyron (ACL) |
| `renly.baratheon` | `lorastyrell` | Baratheon, Small Council | WriteDACL on OU=Crownlands (ACL). Account is sensitive. |
| `stannis.baratheon` | `Drag0nst0ne` | Baratheon, Small Council | GenericAll on kingslanding$ (ACL) |
| `petyer.baelish` | `@littlefinger@` | Small Council | — |
| `lord.varys` | `_W1sper_$` | Small Council | GenericAll on Domain Admins + AdminSDHolder (ACL) |
| `maester.pycelle` | `MaesterOfMaesters` | Small Council | — |

### OU=Westerlands

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `tyron.lannister` | `Alc00L&S3x` | Lannister | Self-membership on Small Council (ACL) |

### OU=Vale

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `lysa.arryn` | `rob1nIsMyHeart` | Arryn, **Exchange Organization Management** | Exchange Admin, local admin on the-eyrie |
| `robin.arryn` | `mommy` | Arryn | — |

### OU=Dorne (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `oberyn.martell` | `V1per_of_D0rne!` | Martell | — |
| `ellaria.sand` | `Poison3dK1ss` | Martell | BEC: receives doran.martell's forwarded mail |
| `doran.martell` | `Patience&Blood` | Martell, Small Council | BEC: mail forwarded to ellaria.sand |
| `trystane.martell` | `myrcella123` | Martell | **AS-REP Roastable** |
| `obara.sand` | `Sp3arAndSh1eld` | Martell | — |
| `nymeria.sand` | `WhipCrack99` | Martell | — |
| `tyene.sand` | `d3adlyKiss` | Martell | — |
| `areo.hotah` | `LongAxe2024` | Martell | — |

### OU=Reach (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `olenna.tyrell` | `Qu33nOfTh0rns!` | Tyrell, Small Council | BEC: inbox rule forwards finance keywords to walder.frey. MSSQL db_datareader on castelblack. |
| `margaery.tyrell` | `GrowStr0ng` | Tyrell | BEC: receives ALL of mace.tyrell's mail |
| `loras.tyrell` | `Kn1ghtOfFlow3rs` | Tyrell, KingsGuard | **Kerberoastable** (`HTTP/highgarden.sevenkingdoms.local`) |
| `mace.tyrell` | `highgarden` | Tyrell, Small Council | BEC: all mail redirected to margaery (never sees his own mail) |
| `randyll.tarly` | `Heartsbane!1` | Tyrell | — |
| `dickon.tarly` | `NotSam123` | Tyrell | **AS-REP Roastable** |
| `garlan.tyrell` | `Gallant!` | Tyrell | — |

### OU=IronIslands (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `balon.greyjoy` | `W3D0NotSow!` | Greyjoy | BEC: euron.greyjoy has FullAccess to his mailbox (hidden) |
| `theon.greyjoy` | `reek2023` | Greyjoy | **Kerberoastable** (`HTTP/pyke.sevenkingdoms.local`). MSSQL: can impersonate walder.frey. |
| `yara.greyjoy` | `Ironb0rn!` | Greyjoy | — |
| `euron.greyjoy` | `S1lenceShip` | Greyjoy | BEC: FullAccess + Send-As on balon.greyjoy's mailbox |
| `victarion.greyjoy` | `IronFl33t` | Greyjoy | — |
| `aeron.greyjoy` | `DrownedG0d` | Greyjoy | — |

### OU=Riverlands (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `edmure.tully` | `Riv3rrun!` | Tully | — |
| `brynden.tully` | `Blackf1sh!` | Tully | — |
| `walder.frey` | `hehehe123` | Frey | BEC: copies all mail to external address. MSSQL db_datareader on castelblack. |
| `lothar.frey` | `LameLothar1` | Frey | — |
| `roslin.frey` | `edmure4ever` | Frey, Tully | — |
| `stevron.frey` | `FrstBorn1` | Frey | — |
| `olyvar.frey` | `squire2024` | Frey | **AS-REP Roastable** |

### OU=Stormlands (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `davos.seaworth` | `On1onKn1ght!` | Stormguard, Small Council | **Kerberoastable** (`HTTP/capewrath.sevenkingdoms.local`). MSSQL login on castelblack. |
| `gendry.baratheon` | `Hamm3r_Time` | Baratheon, Stormguard | — |
| `brienne.tarth` | `Oath_K33per!` | KingsGuard, Stormguard | **Kerberoastable** (`HTTP/evenfall.sevenkingdoms.local`). **MSSQL sysadmin on castelblack** (over-privileged). |
| `beric.dondarrion` | `L1ghtBr1ng3r` | Stormguard | — |
| `podrick.payne` | `loyalsquire` | Stormguard | **AS-REP Roastable** |
| `selyse.baratheon` | `RhLorBurns` | Baratheon | — |

---

## north.sevenkingdoms.local — All Users

### CN=Users (base)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `arya.stark` | `Needle` | Stark | MSSQL impersonate dbo on master+msdb (castelblack) |
| `eddard.stark` | `FightP3aceAndHonor!` | Stark, **Domain Admins** | Domain Admin |
| `catelyn.stark` | `robbsansabradonaryarickon` | Stark | Local admin on winterfell |
| `robb.stark` | `sexywolfy` | Stark | Local admin on winterfell. Autologon + saved creds for castelblack. |
| `sansa.stark` | `345ertdfg` | Stark | **Kerberoastable** (`HTTP/eyrie.north.sevenkingdoms.local`) |
| `brandon.stark` | `iseedeadpeople` | Stark | MSSQL impersonate jon.snow on castelblack |
| `rickon.stark` | `Winter2022` | Stark | — |
| `hodor` | `hodor` | Stark | — |
| `jon.snow` | `iknownothing` | Stark, Night Watch | **Kerberoastable** (`HTTP/thewall.north.sevenkingdoms.local`). MSSQL sysadmin on castelblack. Linked server to braavos as sa. |
| `samwell.tarly` | `Heartsbane` | Night Watch | Password in description field. MSSQL impersonate sa on castelblack. |
| `jeor.mormont` | `_L0ngCl@w_` | Night Watch, Mormont | Local admin on castelblack |
| `sql_svc` | `YouWillNotKerboroast1ngMeeeeee` | — | **Kerberoastable**. MSSQL service account. |

### CN=Users (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `meera.reed` | `Crannog!23` | Reed, Stark | — |
| `jojen.reed` | `Gr33nDr3ams` | Reed | — |
| `benjen.stark` | `F1rstRang3r!` | Stark, Night Watch | — |
| `lyanna.mormont` | `B3arIsland!` | Mormont, Stark | — |

### OU=Wildlings (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `tormund.giantsbane` | `giantsmilk!` | Freefolk | **Kerberoastable** (`HTTP/wildlings.north.sevenkingdoms.local`) |
| `mance.rayder` | `K1ngBey0ndTheWall` | Freefolk | — |
| `ygritte` | `youknownothing` | Freefolk | — |
| `craster` | `k33p2024` | Freefolk | **AS-REP Roastable** |
| `styr` | `Th3nnW4rr1or` | Freefolk | — |

### OU=Bolton (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `roose.bolton` | `0urBladesAreSharp!` | Bolton | **Kerberoastable** (`HTTP/dreadfort.north.sevenkingdoms.local`). MSSQL login on castelblack. |
| `ramsay.bolton` | `Ree3k_Ree3k` | Bolton | **AS-REP Roastable** |
| `locke` | `hunt3rsCatch` | Bolton | — |

### OU=Manderly (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `wyman.manderly` | `Th3N0rthR3memb3rs!` | Manderly, Stark | MSSQL login on castelblack |
| `wylis.manderly` | `WH4rb0r2024` | Manderly | — |

---

## essos.local — All Users

### CN=Users (base)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `daenerys.targaryen` | `BurnThemAll!` | Targaryen, **Domain Admins** | Domain Admin |
| `viserys.targaryen` | `GoldCrown` | Targaryen | CA Manager for ESC7 (ACL) |
| `khal.drogo` | `horse` | Dothraki | GenericAll on viserys, ESC4 template, missandei (ACLs). Local admin on braavos. MSSQL sysadmin on braavos. |
| `jorah.mormont` | `H0nnor!` | Targaryen | LAPS reader on essos. MSSQL impersonate sa on braavos. |
| `missandei` | `fr3edom` | — | GenericAll on khal.drogo + GenericWrite on viserys (ACLs) |
| `drogon` | `Dracarys` | Dragons | GenericAll from gmsaDragon$ (ACL) |
| `sql_svc` | `YouWillNotKerboroast1ngMeeeeee` | — | **Kerberoastable**. MSSQL service account. |

### OU=Meereen (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `grey.worm` | `Unsull13d!` | Unsullied, Targaryen | — |
| `daario.naharis` | `Sw0rdAndCharm` | SecondSons | **Kerberoastable** (`HTTP/secondsons.essos.local`) |
| `hizdahr.loraq` | `N0bleBlood` | Masters | **AS-REP Roastable** |
| `barristan.selmy` | `B0ldBarr1stan!` | Targaryen | — |
| `tyrion.essos` | `IdrinkAndIkn0w` | Targaryen | — |

### OU=Pentos (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `illyrio.mopatis` | `Ch33seAndW1ne` | Merchants | — |
| `varys.essos` | `Wh1spers&B1rds` | Merchants | — |

### OU=Braavos (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `syrio.forel` | `N0tToday!` | FacelessMen | — |
| `jaqen.hghar` | `V4larM0rghul1s` | FacelessMen | — |
| `tycho.nestoris` | `Ir0nBank_Pays` | Merchants | **Kerberoastable** (`HTTP/ironbank.essos.local`) |
| `izembaro` | `theatre2024` | — | **AS-REP Roastable** |

### OU=Volantis (expansion)

| Username | Password | Groups | Notes |
|----------|----------|--------|-------|
| `kinvara` | `L0rdOfL1ght!` | — | — |

---

## MSSQL Access Summary

### castelblack (SRV02) — `SQLEXPRESS`

| Login | Role/Permission | Notes |
|-------|----------------|-------|
| `NORTH\jon.snow` | sysadmin | Linked server to braavos as sa |
| `NORTH\samwell.tarly` | impersonate sa | — |
| `NORTH\brandon.stark` | impersonate jon.snow | — |
| `NORTH\arya.stark` | impersonate dbo (master + msdb) | — |
| `SEVENKINGDOMS\brienne.tarth` | **sysadmin** | Over-privileged (expansion) |
| `SEVENKINGDOMS\olenna.tyrell` | db_datareader (master) | — |
| `SEVENKINGDOMS\walder.frey` | db_datareader (master) | — |
| `SEVENKINGDOMS\theon.greyjoy` | impersonate walder.frey | — |
| `SEVENKINGDOMS\doran.martell` | login only | — |
| `SEVENKINGDOMS\davos.seaworth` | login only | — |
| `NORTH\wyman.manderly` | login only | — |
| `NORTH\roose.bolton` | login only | — |
| `finance_reports` (SQL auth) | login only | Weak password: `reports2024` |

### braavos (SRV03) — `SQLEXPRESS`

| Login | Role/Permission | Notes |
|-------|----------------|-------|
| `ESSOS\khal.drogo` | sysadmin | Linked server to castelblack as sa |
| `ESSOS\jorah.mormont` | impersonate sa | — |

### Linked Server Chain

```
castelblack (jon.snow as sa) <---> braavos (khal.drogo as sa)
```

Cross-forest MSSQL impersonation via linked servers.

---

## File Shares

### castelblack (SRV02)

| Share | Full Access | Read Access | Loot Files |
|-------|------------|-------------|------------|
| `\\castelblack\thewall` | NORTH\Stark | Users | — |
| `\\castelblack\all` | — | — | `arya.txt` |
| `\\castelblack\Dorne` | Martell | Domain Users | Trade routes, contact emails |
| `\\castelblack\IronIslands` | Greyjoy | Domain Users | Fleet manifest, dock codes |
| `\\castelblack\Reach` | Tyrell | Domain Users | Harvest report |
| `\\castelblack\Riverlands` | Tully, Frey | Domain Users | Bridge toll records |
| `\\castelblack\Finance` | Small Council | Domain Users | Budget, vendor payments, wire transfer template |
| `\\castelblack\HR` | Small Council | Domain Users + NORTH\Domain Users | New starter list with default password policy, salary bands |

---

## BEC Attack Scenarios

| # | Technique | Victim | Attacker | How to Detect |
|---|-----------|--------|----------|---------------|
| 1 | Internal mail forwarding | `doran.martell` | `ellaria.sand` | `Get-Mailbox doran.martell \| FL ForwardingAddress` |
| 2 | Hidden inbox rule | `olenna.tyrell` | `walder.frey` | `Get-InboxRule -Mailbox olenna.tyrell` |
| 3 | Full mail redirect | `mace.tyrell` | `margaery.tyrell` | `Get-Mailbox mace.tyrell \| FL ForwardingAddress,DeliverToMailboxAndForward` |
| 4 | External SMTP forward | `walder.frey` | `external-twins.com` | `Get-Mailbox walder.frey \| FL ForwardingSMTPAddress` |
| 5 | Hidden mailbox delegation | `balon.greyjoy` | `euron.greyjoy` | `Get-MailboxPermission balon.greyjoy` |
| 6 | Send-As via FullAccess | `balon.greyjoy` | `euron.greyjoy` | Same as above (AutoMapping disabled) |

---

## Domain Trusts

| Trust | Type | Direction |
|-------|------|-----------|
| sevenkingdoms.local ↔ north.sevenkingdoms.local | Parent/Child (same forest) | Bidirectional |
| sevenkingdoms.local ↔ essos.local | Forest trust | Bidirectional |

---

## Server Summary

| VM | Hostname | IP | OS | RAM | Domain | Services |
|----|----------|-----|-----|-----|--------|----------|
| DC01 | kingslanding | 192.168.10.10 | Server 2019 | 3 GB | sevenkingdoms.local | AD DS, DNS, ADCS, IIS |
| DC02 | winterfell | 192.168.10.11 | Server 2019 | 3 GB | north.sevenkingdoms.local | AD DS, DNS |
| DC03 | meereen | 192.168.10.12 | Server 2016 | 3 GB | essos.local | AD DS, DNS, ADCS |
| SRV01 | the-eyrie | 192.168.10.21 | Server 2019 | 12 GB | sevenkingdoms.local | Exchange 2019 |
| SRV02 | castelblack | 192.168.10.22 | Server 2019 | 5 GB | north.sevenkingdoms.local | MSSQL, IIS |
| SRV03 | braavos | 192.168.10.23 | Server 2016 | 4 GB | essos.local | MSSQL, ADCS |

**RDP access** via SSH tunnel through the provisioning VM. See [README.md](README.md#accessing-the-lab-rdp) for details.
