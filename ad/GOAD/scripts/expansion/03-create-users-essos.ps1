# 03-create-users-essos.ps1
# Run on DC03 (meereen) as Domain Admin
# Creates additional users in essos.local

Import-Module ActiveDirectory

$domain = "essos.local"
$domainDN = "DC=essos,DC=local"

# --- Create OUs ---
$ous = @("Meereen", "Pentos", "Braavos", "Volantis")
foreach ($ou in $ous) {
    try {
        New-ADOrganizationalUnit -Name $ou -Path $domainDN -ProtectedFromAccidentalDeletion $false
        Write-Host "[+] Created OU: $ou" -ForegroundColor Green
    } catch {
        Write-Host "[=] OU exists: $ou" -ForegroundColor Yellow
    }
}

# --- Groups ---
$groups = @(
    @{ Name="Unsullied";   Path="OU=Meereen,$domainDN" }
    @{ Name="SecondSons";  Path="OU=Meereen,$domainDN" }
    @{ Name="Masters";     Path="OU=Meereen,$domainDN" }
    @{ Name="FacelessMen"; Path="OU=Braavos,$domainDN" }
    @{ Name="Merchants";   Path="OU=Pentos,$domainDN" }
)

foreach ($g in $groups) {
    try {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $g.Path -Description $g.Name
        Write-Host "[+] Created group: $($g.Name)" -ForegroundColor Green
    } catch {
        Write-Host "[=] Group exists: $($g.Name)" -ForegroundColor Yellow
    }
}

# --- Users ---
$users = @(
    # OU=Meereen — Daenerys's court
    @{ Sam="grey.worm";         First="Grey";    Last="Worm";      Pass="Unsull13d!";           OU="OU=Meereen,$domainDN";  Groups=@("Unsullied","Targaryen");  Desc="Grey Worm - Commander of the Unsullied"; City="Meereen" }
    @{ Sam="daario.naharis";    First="Daario";  Last="Naharis";   Pass="Sw0rdAndCharm";        OU="OU=Meereen,$domainDN";  Groups=@("SecondSons");             Desc="Daario Naharis - Captain of the Second Sons"; City="Meereen" }
    @{ Sam="hizdahr.loraq";     First="Hizdahr"; Last="Loraq";     Pass="N0bleBlood";           OU="OU=Meereen,$domainDN";  Groups=@("Masters");                Desc="Hizdahr zo Loraq - Noble of Meereen"; City="Meereen" }
    @{ Sam="barristan.selmy";   First="Barristan"; Last="Selmy";   Pass="B0ldBarr1stan!";       OU="OU=Meereen,$domainDN";  Groups=@("Targaryen");              Desc="Barristan Selmy - Barristan the Bold"; City="Meereen" }
    @{ Sam="tyrion.lannister";  First="Tyrion";  Last="Lannister"; Pass="IdrinkAndIkn0w";       OU="OU=Meereen,$domainDN";  Groups=@("Targaryen");              Desc="Tyrion Lannister - Hand of the Queen (Essos)"; City="Meereen" }

    # OU=Pentos — Merchants and schemers
    @{ Sam="illyrio.mopatis";   First="Illyrio"; Last="Mopatis";   Pass="Ch33seAndW1ne";        OU="OU=Pentos,$domainDN";   Groups=@("Merchants");              Desc="Illyrio Mopatis - Magister of Pentos"; City="Pentos" }
    @{ Sam="varys.essos";       First="Varys";   Last="Spider";    Pass="Wh1spers&B1rds";       OU="OU=Pentos,$domainDN";   Groups=@("Merchants");              Desc="Varys - The Spider (Essos identity)"; City="Pentos" }
    @{ Sam="kinvara";           First="Kinvara"; Last="Volantis";  Pass="L0rdOfL1ght!";         OU="OU=Volantis,$domainDN"; Groups=@();                         Desc="Kinvara - Red Priestess of Volantis"; City="Volantis" }

    # OU=Braavos — Faceless Men and finance
    @{ Sam="syrio.forel";       First="Syrio";   Last="Forel";     Pass="N0tToday!";            OU="OU=Braavos,$domainDN";  Groups=@("FacelessMen");            Desc="Syrio Forel - First Sword of Braavos"; City="Braavos" }
    @{ Sam="jaqen.hghar";       First="Jaqen";   Last="Hghar";     Pass="V4larM0rghul1s";       OU="OU=Braavos,$domainDN";  Groups=@("FacelessMen");            Desc="Jaqen H'ghar - A man has no name"; City="Braavos" }
    @{ Sam="tycho.nestoris";    First="Tycho";   Last="Nestoris";  Pass="Ir0nBank_Pays";        OU="OU=Braavos,$domainDN";  Groups=@("Merchants");              Desc="Tycho Nestoris - Iron Bank representative"; City="Braavos" }
    @{ Sam="izembaro";          First="Izembaro"; Last="Actor";    Pass="theatre2024";          OU="OU=Braavos,$domainDN";  Groups=@();                         Desc="Izembaro - Leader of a Braavosi theatre troupe"; City="Braavos" }
)

foreach ($u in $users) {
    try {
        $secPass = ConvertTo-SecureString $u.Pass -AsPlainText -Force
        New-ADUser -SamAccountName $u.Sam `
            -UserPrincipalName "$($u.Sam)@$domain" `
            -Name "$($u.First) $($u.Last)" `
            -GivenName $u.First `
            -Surname $u.Last `
            -Description $u.Desc `
            -City $u.City `
            -Path $u.OU `
            -AccountPassword $secPass `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -ChangePasswordAtLogon $false

        foreach ($grp in $u.Groups) {
            Add-ADGroupMember -Identity $grp -Members $u.Sam
        }

        Write-Host "[+] Created: $($u.Sam) in $($u.OU)" -ForegroundColor Green
    } catch {
        Write-Host "[!] Failed or exists: $($u.Sam) - $_" -ForegroundColor Red
    }
}

# --- SPNs ---
Write-Host "`n[*] Setting SPNs..." -ForegroundColor Cyan
Set-ADUser -Identity "tycho.nestoris" -ServicePrincipalNames @{Add="HTTP/ironbank.essos.local"}
Set-ADUser -Identity "daario.naharis" -ServicePrincipalNames @{Add="HTTP/secondsons.essos.local"}
Write-Host "[+] SPNs set for tycho.nestoris and daario.naharis" -ForegroundColor Green

# --- AS-REP Roastable ---
Write-Host "[*] Setting AS-REP Roastable accounts..." -ForegroundColor Cyan
Set-ADAccountControl -Identity "izembaro" -DoesNotRequirePreAuth $true
Set-ADAccountControl -Identity "hizdahr.loraq" -DoesNotRequirePreAuth $true
Write-Host "[+] AS-REP Roastable: izembaro, hizdahr.loraq" -ForegroundColor Green

Write-Host "`n[*] essos.local user expansion complete. $($users.Count) users created." -ForegroundColor Cyan
