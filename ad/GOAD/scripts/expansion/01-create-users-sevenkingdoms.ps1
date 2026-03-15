# 01-create-users-sevenkingdoms.ps1
# Run on DC01 (kingslanding) as Domain Admin
# Creates users in the empty OUs of sevenkingdoms.local

Import-Module ActiveDirectory

$domain = "sevenkingdoms.local"
$domainDN = "DC=sevenkingdoms,DC=local"

# --- Groups per region ---
$groups = @(
    @{ Name="Martell";   Path="OU=Dorne,$domainDN";       ManagedBy="oberyn.martell" }
    @{ Name="Tyrell";    Path="OU=Reach,$domainDN";        ManagedBy="olenna.tyrell" }
    @{ Name="Greyjoy";   Path="OU=IronIslands,$domainDN";  ManagedBy="balon.greyjoy" }
    @{ Name="Tully";     Path="OU=Riverlands,$domainDN";   ManagedBy="edmure.tully" }
    @{ Name="Frey";      Path="OU=Riverlands,$domainDN";   ManagedBy="walder.frey" }
    @{ Name="Stormguard"; Path="OU=Stormlands,$domainDN";  ManagedBy="davos.seaworth" }
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
    # OU=Dorne — House Martell
    @{ Sam="oberyn.martell";   First="Oberyn";   Last="Martell";   Pass="V1per_of_D0rne!";       OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Oberyn Martell - The Red Viper"; City="Sunspear" }
    @{ Sam="ellaria.sand";     First="Ellaria";  Last="Sand";      Pass="Poison3dK1ss";           OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Ellaria Sand - Paramour"; City="Sunspear" }
    @{ Sam="doran.martell";    First="Doran";    Last="Martell";   Pass="Patience&Blood";         OU="OU=Dorne,$domainDN";       Groups=@("Martell","Small Council"); Desc="Doran Martell - Prince of Dorne"; City="Sunspear" }
    @{ Sam="trystane.martell"; First="Trystane"; Last="Martell";   Pass="myrcella123";            OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Trystane Martell"; City="Sunspear" }
    @{ Sam="obara.sand";       First="Obara";    Last="Sand";      Pass="Sp3arAndSh1eld";         OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Obara Sand - Sand Snake"; City="Sunspear" }
    @{ Sam="nymeria.sand";     First="Nymeria";  Last="Sand";      Pass="WhipCrack99";            OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Nymeria Sand - Sand Snake"; City="Sunspear" }
    @{ Sam="tyene.sand";       First="Tyene";    Last="Sand";      Pass="d3adlyKiss";             OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Tyene Sand - Sand Snake"; City="Sunspear" }
    @{ Sam="areo.hotah";       First="Areo";     Last="Hotah";     Pass="LongAxe2024";            OU="OU=Dorne,$domainDN";       Groups=@("Martell");        Desc="Areo Hotah - Captain of Guard"; City="Sunspear" }

    # OU=Reach — House Tyrell
    @{ Sam="olenna.tyrell";    First="Olenna";   Last="Tyrell";    Pass="Qu33nOfTh0rns!";         OU="OU=Reach,$domainDN";       Groups=@("Tyrell","Small Council"); Desc="Olenna Tyrell - Queen of Thorns"; City="Highgarden" }
    @{ Sam="margaery.tyrell";  First="Margaery"; Last="Tyrell";    Pass="GrowStr0ng";             OU="OU=Reach,$domainDN";       Groups=@("Tyrell");         Desc="Margaery Tyrell"; City="Highgarden" }
    @{ Sam="loras.tyrell";     First="Loras";    Last="Tyrell";    Pass="Kn1ghtOfFlow3rs";        OU="OU=Reach,$domainDN";       Groups=@("Tyrell","KingsGuard"); Desc="Loras Tyrell - Knight of Flowers"; City="Highgarden" }
    @{ Sam="mace.tyrell";      First="Mace";     Last="Tyrell";    Pass="highgarden";             OU="OU=Reach,$domainDN";       Groups=@("Tyrell","Small Council"); Desc="Mace Tyrell - Lord of Highgarden"; City="Highgarden" }
    @{ Sam="randyll.tarly";    First="Randyll";  Last="Tarly";     Pass="Heartsbane!1";           OU="OU=Reach,$domainDN";       Groups=@("Tyrell");         Desc="Randyll Tarly - Lord of Horn Hill"; City="Horn Hill" }
    @{ Sam="dickon.tarly";     First="Dickon";   Last="Tarly";     Pass="NotSam123";              OU="OU=Reach,$domainDN";       Groups=@("Tyrell");         Desc="Dickon Tarly"; City="Horn Hill" }
    @{ Sam="garlan.tyrell";    First="Garlan";   Last="Tyrell";    Pass="Gallant!";               OU="OU=Reach,$domainDN";       Groups=@("Tyrell");         Desc="Garlan Tyrell - The Gallant"; City="Highgarden" }

    # OU=IronIslands — House Greyjoy
    @{ Sam="balon.greyjoy";    First="Balon";    Last="Greyjoy";   Pass="W3D0NotSow!";            OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Balon Greyjoy - Lord of the Iron Islands"; City="Pyke" }
    @{ Sam="theon.greyjoy";    First="Theon";    Last="Greyjoy";   Pass="reek2023";               OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Theon Greyjoy"; City="Pyke" }
    @{ Sam="yara.greyjoy";     First="Yara";     Last="Greyjoy";   Pass="Ironb0rn!";              OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Yara Greyjoy - Captain"; City="Pyke" }
    @{ Sam="euron.greyjoy";    First="Euron";    Last="Greyjoy";   Pass="S1lenceShip";            OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Euron Greyjoy - Crow's Eye"; City="Pyke" }
    @{ Sam="victarion.greyjoy"; First="Victarion"; Last="Greyjoy"; Pass="IronFl33t";              OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Victarion Greyjoy - Iron Captain"; City="Pyke" }
    @{ Sam="aeron.greyjoy";    First="Aeron";    Last="Greyjoy";   Pass="DrownedG0d";             OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");        Desc="Aeron Greyjoy - Damphair"; City="Pyke" }

    # OU=Riverlands — House Tully & House Frey
    @{ Sam="edmure.tully";     First="Edmure";   Last="Tully";     Pass="Riv3rrun!";              OU="OU=Riverlands,$domainDN";  Groups=@("Tully");          Desc="Edmure Tully - Lord of Riverrun"; City="Riverrun" }
    @{ Sam="brynden.tully";    First="Brynden";  Last="Tully";     Pass="Blackf1sh!";             OU="OU=Riverlands,$domainDN";  Groups=@("Tully");          Desc="Brynden Tully - The Blackfish"; City="Riverrun" }
    @{ Sam="walder.frey";      First="Walder";   Last="Frey";      Pass="hehehe123";              OU="OU=Riverlands,$domainDN";  Groups=@("Frey");           Desc="Walder Frey - The Late Lord Frey"; City="The Twins" }
    @{ Sam="lothar.frey";      First="Lothar";   Last="Frey";      Pass="LameLothar1";            OU="OU=Riverlands,$domainDN";  Groups=@("Frey");           Desc="Lothar Frey - Lame Lothar"; City="The Twins" }
    @{ Sam="roslin.frey";      First="Roslin";   Last="Frey";      Pass="edmure4ever";            OU="OU=Riverlands,$domainDN";  Groups=@("Frey","Tully");   Desc="Roslin Frey - Wife of Edmure"; City="The Twins" }
    @{ Sam="stevron.frey";     First="Stevron";  Last="Frey";      Pass="FrstBorn1";              OU="OU=Riverlands,$domainDN";  Groups=@("Frey");           Desc="Stevron Frey - Eldest Son"; City="The Twins" }
    @{ Sam="olyvar.frey";      First="Olyvar";   Last="Frey";      Pass="squire2024";             OU="OU=Riverlands,$domainDN";  Groups=@("Frey");           Desc="Olyvar Frey - Squire to Robb Stark"; City="The Twins" }

    # OU=Stormlands — Various houses
    @{ Sam="davos.seaworth";   First="Davos";    Last="Seaworth";  Pass="On1onKn1ght!";           OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard","Small Council"); Desc="Davos Seaworth - The Onion Knight"; City="Cape Wrath" }
    @{ Sam="gendry.baratheon"; First="Gendry";   Last="Baratheon"; Pass="Hamm3r_Time";            OU="OU=Stormlands,$domainDN";  Groups=@("Baratheon","Stormguard"); Desc="Gendry Baratheon - Legitimised bastard"; City="Storm's End" }
    @{ Sam="brienne.tarth";    First="Brienne";  Last="Tarth";     Pass="Oath_K33per!";           OU="OU=Stormlands,$domainDN";  Groups=@("KingsGuard","Stormguard"); Desc="Brienne of Tarth"; City="Evenfall Hall" }
    @{ Sam="beric.dondarrion"; First="Beric";    Last="Dondarrion"; Pass="L1ghtBr1ng3r";          OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard");     Desc="Beric Dondarrion - Lord of Blackhaven"; City="Blackhaven" }
    @{ Sam="podrick.payne";    First="Podrick";  Last="Payne";     Pass="loyalsquire";            OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard");     Desc="Podrick Payne - Squire"; City="Storm's End" }
    @{ Sam="selyse.baratheon"; First="Selyse";   Last="Baratheon"; Pass="RhLorBurns";             OU="OU=Stormlands,$domainDN";  Groups=@("Baratheon");      Desc="Selyse Baratheon - Wife of Stannis"; City="Dragonstone" }
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

# --- SPNs for Kerberoasting targets ---
Write-Host "`n[*] Setting SPNs for Kerberoastable accounts..." -ForegroundColor Cyan
$spns = @(
    @{ Sam="loras.tyrell";     SPN="HTTP/highgarden.sevenkingdoms.local" }
    @{ Sam="theon.greyjoy";    SPN="HTTP/pyke.sevenkingdoms.local" }
    @{ Sam="brienne.tarth";    SPN="HTTP/evenfall.sevenkingdoms.local" }
    @{ Sam="davos.seaworth";   SPN="HTTP/capewrath.sevenkingdoms.local" }
)

foreach ($s in $spns) {
    try {
        Set-ADUser -Identity $s.Sam -ServicePrincipalNames @{Add=$s.SPN}
        Write-Host "[+] SPN set: $($s.Sam) -> $($s.SPN)" -ForegroundColor Green
    } catch {
        Write-Host "[!] SPN failed: $($s.Sam) - $_" -ForegroundColor Red
    }
}

# --- AS-REP Roastable accounts (no preauth required) ---
Write-Host "`n[*] Setting AS-REP Roastable accounts..." -ForegroundColor Cyan
$asrep = @("trystane.martell", "podrick.payne", "olyvar.frey", "dickon.tarly")
foreach ($a in $asrep) {
    try {
        Set-ADAccountControl -Identity $a -DoesNotRequirePreAuth $true
        Write-Host "[+] AS-REP Roastable: $a" -ForegroundColor Green
    } catch {
        Write-Host "[!] AS-REP failed: $a - $_" -ForegroundColor Red
    }
}

Write-Host "`n[*] sevenkingdoms.local user expansion complete. $($users.Count) users created." -ForegroundColor Cyan
