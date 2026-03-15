# 02-create-users-north.ps1
# Run on DC02 (winterfell) as Domain Admin
# Creates additional users in north.sevenkingdoms.local

Import-Module ActiveDirectory

$domain = "north.sevenkingdoms.local"
$domainDN = "DC=north,DC=sevenkingdoms,DC=local"

# --- Create OUs ---
$ous = @("Wildlings", "Bolton", "Manderly")
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
    @{ Name="Freefolk";  Path="OU=Wildlings,$domainDN";  ManagedBy=$null }
    @{ Name="Bolton";    Path="OU=Bolton,$domainDN";      ManagedBy=$null }
    @{ Name="Manderly";  Path="OU=Manderly,$domainDN";    ManagedBy=$null }
    @{ Name="Reed";      Path="CN=Users,$domainDN";       ManagedBy=$null }
)

foreach ($g in $groups) {
    try {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $g.Path -Description "House $($g.Name)"
        Write-Host "[+] Created group: $($g.Name)" -ForegroundColor Green
    } catch {
        Write-Host "[=] Group exists: $($g.Name)" -ForegroundColor Yellow
    }
}

# --- Users ---
$users = @(
    # OU=Wildlings — Freefolk
    @{ Sam="tormund.giantsbane"; First="Tormund"; Last="Giantsbane"; Pass="giantsmilk!";         OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");            Desc="Tormund Giantsbane - Wildling leader"; City="Beyond the Wall" }
    @{ Sam="mance.rayder";       First="Mance";   Last="Rayder";     Pass="K1ngBey0ndTheWall";   OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");            Desc="Mance Rayder - King-Beyond-the-Wall"; City="Beyond the Wall" }
    @{ Sam="ygritte";            First="Ygritte"; Last="Wildling";   Pass="youknownothing";      OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");            Desc="Ygritte - Kissed by fire"; City="Beyond the Wall" }
    @{ Sam="craster";            First="Craster"; Last="Wildling";   Pass="k33p2024";            OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");            Desc="Craster - Keeps to himself"; City="Craster's Keep" }
    @{ Sam="styr";               First="Styr";    Last="Thenn";      Pass="Th3nnW4rr1or";        OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");            Desc="Styr - Magnar of Thenns"; City="Beyond the Wall" }

    # OU=Bolton — House Bolton
    @{ Sam="roose.bolton";       First="Roose";   Last="Bolton";     Pass="0urBladesAreSharp!";  OU="OU=Bolton,$domainDN";    Groups=@("Bolton");              Desc="Roose Bolton - Lord of the Dreadfort"; City="Dreadfort" }
    @{ Sam="ramsay.bolton";      First="Ramsay";  Last="Bolton";     Pass="Ree3k_Ree3k";         OU="OU=Bolton,$domainDN";    Groups=@("Bolton");              Desc="Ramsay Bolton - The Bastard of Bolton"; City="Dreadfort" }
    @{ Sam="locke";              First="Locke";   Last="Bolton";     Pass="hunt3rsCatch";         OU="OU=Bolton,$domainDN";    Groups=@("Bolton");              Desc="Locke - Bolton man-at-arms"; City="Dreadfort" }

    # OU=Manderly
    @{ Sam="wyman.manderly";     First="Wyman";   Last="Manderly";   Pass="Th3N0rthR3memb3rs!";  OU="OU=Manderly,$domainDN";  Groups=@("Manderly","Stark");    Desc="Wyman Manderly - Lord of White Harbor"; City="White Harbor" }
    @{ Sam="wylis.manderly";     First="Wylis";   Last="Manderly";   Pass="WH4rb0r2024";         OU="OU=Manderly,$domainDN";  Groups=@("Manderly");            Desc="Wylis Manderly - Heir to White Harbor"; City="White Harbor" }

    # CN=Users — Other Northerners
    @{ Sam="meera.reed";         First="Meera";   Last="Reed";       Pass="Crannog!23";           OU="CN=Users,$domainDN";     Groups=@("Reed","Stark");        Desc="Meera Reed - Protector of Bran"; City="Greywater Watch" }
    @{ Sam="jojen.reed";         First="Jojen";   Last="Reed";       Pass="Gr33nDr3ams";          OU="CN=Users,$domainDN";     Groups=@("Reed");                Desc="Jojen Reed - The Greenseer"; City="Greywater Watch" }
    @{ Sam="benjen.stark";       First="Benjen";  Last="Stark";      Pass="F1rstRang3r!";         OU="CN=Users,$domainDN";     Groups=@("Stark","Night Watch"); Desc="Benjen Stark - First Ranger"; City="Castle Black" }
    @{ Sam="lyanna.mormont";     First="Lyanna";  Last="Mormont";    Pass="B3arIsland!";          OU="CN=Users,$domainDN";     Groups=@("Mormont","Stark");     Desc="Lyanna Mormont - Lady of Bear Island"; City="Bear Island" }
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
Set-ADUser -Identity "tormund.giantsbane" -ServicePrincipalNames @{Add="HTTP/wildlings.north.sevenkingdoms.local"}
Set-ADUser -Identity "roose.bolton" -ServicePrincipalNames @{Add="HTTP/dreadfort.north.sevenkingdoms.local"}
Write-Host "[+] SPNs set for tormund.giantsbane and roose.bolton" -ForegroundColor Green

# --- AS-REP Roastable ---
Write-Host "[*] Setting AS-REP Roastable accounts..." -ForegroundColor Cyan
Set-ADAccountControl -Identity "craster" -DoesNotRequirePreAuth $true
Set-ADAccountControl -Identity "ramsay.bolton" -DoesNotRequirePreAuth $true
Write-Host "[+] AS-REP Roastable: craster, ramsay.bolton" -ForegroundColor Green

Write-Host "`n[*] north.sevenkingdoms.local user expansion complete. $($users.Count) users created." -ForegroundColor Cyan
