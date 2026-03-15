# run-all-from-dc01.ps1
# Run from DC01 (kingslanding) as SEVENKINGDOMS\cersei.lannister or Administrator
# Executes all expansion scripts across the lab via PowerShell Remoting

$ErrorActionPreference = "Continue"

# Credentials for cross-domain remoting
$sevenkingdomsAdmin = "SEVENKINGDOMS\cersei.lannister"
$northAdmin = "NORTH\eddard.stark"
$essosAdmin = "ESSOS\daenerys.targaryen"

# You'll be prompted for passwords (or hardcode for lab use)
Write-Host "=== GOAD Lab Expansion - Master Runner ===" -ForegroundColor Cyan
Write-Host "Running from: $env:COMPUTERNAME ($env:USERDOMAIN)" -ForegroundColor Cyan
Write-Host ""

# For a lab environment, we can use the known passwords
$sevenkingdomsPass = ConvertTo-SecureString "il0vejaime" -AsPlainText -Force
$northPass = ConvertTo-SecureString "FightP3aceAndHonor!" -AsPlainText -Force
$essosPass = ConvertTo-SecureString "BurnThemAll!" -AsPlainText -Force

$credSK = New-Object System.Management.Automation.PSCredential($sevenkingdomsAdmin, $sevenkingdomsPass)
$credNorth = New-Object System.Management.Automation.PSCredential($northAdmin, $northPass)
$credEssos = New-Object System.Management.Automation.PSCredential($essosAdmin, $essosPass)

# ================================================================
# STEP 1: Create users on DC01 (sevenkingdoms.local) — LOCAL
# ================================================================
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "STEP 1/5: sevenkingdoms.local users (DC01 - local)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Import-Module ActiveDirectory

$domain = "sevenkingdoms.local"
$domainDN = "DC=sevenkingdoms,DC=local"

# Groups
$groups = @(
    @{ Name="Martell";    Path="OU=Dorne,$domainDN" }
    @{ Name="Tyrell";     Path="OU=Reach,$domainDN" }
    @{ Name="Greyjoy";    Path="OU=IronIslands,$domainDN" }
    @{ Name="Tully";      Path="OU=Riverlands,$domainDN" }
    @{ Name="Frey";       Path="OU=Riverlands,$domainDN" }
    @{ Name="Stormguard"; Path="OU=Stormlands,$domainDN" }
)

foreach ($g in $groups) {
    try {
        New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Path $g.Path -Description "House $($g.Name)" -ErrorAction Stop
        Write-Host "[+] Group: $($g.Name)" -ForegroundColor Green
    } catch { Write-Host "[=] Group exists: $($g.Name)" -ForegroundColor DarkGray }
}

$skUsers = @(
    # Dorne
    @{ Sam="oberyn.martell";    First="Oberyn";    Last="Martell";    Pass="V1per_of_D0rne!";    OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Oberyn Martell - The Red Viper";              City="Sunspear" }
    @{ Sam="ellaria.sand";      First="Ellaria";   Last="Sand";       Pass="Poison3dK1ss";       OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Ellaria Sand - Paramour";                     City="Sunspear" }
    @{ Sam="doran.martell";     First="Doran";     Last="Martell";    Pass="Patience&Blood";     OU="OU=Dorne,$domainDN";       Groups=@("Martell","Small Council");          Desc="Doran Martell - Prince of Dorne";             City="Sunspear" }
    @{ Sam="trystane.martell";  First="Trystane";  Last="Martell";    Pass="myrcella123";        OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Trystane Martell";                            City="Sunspear" }
    @{ Sam="obara.sand";        First="Obara";     Last="Sand";       Pass="Sp3arAndSh1eld";     OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Obara Sand - Sand Snake";                     City="Sunspear" }
    @{ Sam="nymeria.sand";      First="Nymeria";   Last="Sand";       Pass="WhipCrack99";        OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Nymeria Sand - Sand Snake";                   City="Sunspear" }
    @{ Sam="tyene.sand";        First="Tyene";     Last="Sand";       Pass="d3adlyKiss";         OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Tyene Sand - Sand Snake";                     City="Sunspear" }
    @{ Sam="areo.hotah";        First="Areo";      Last="Hotah";      Pass="LongAxe2024";        OU="OU=Dorne,$domainDN";       Groups=@("Martell");                          Desc="Areo Hotah - Captain of Guard";               City="Sunspear" }
    # Reach
    @{ Sam="olenna.tyrell";     First="Olenna";    Last="Tyrell";     Pass="Qu33nOfTh0rns!";     OU="OU=Reach,$domainDN";       Groups=@("Tyrell","Small Council");           Desc="Olenna Tyrell - Queen of Thorns";             City="Highgarden" }
    @{ Sam="margaery.tyrell";   First="Margaery";  Last="Tyrell";     Pass="GrowStr0ng";         OU="OU=Reach,$domainDN";       Groups=@("Tyrell");                           Desc="Margaery Tyrell";                             City="Highgarden" }
    @{ Sam="loras.tyrell";      First="Loras";     Last="Tyrell";     Pass="Kn1ghtOfFlow3rs";    OU="OU=Reach,$domainDN";       Groups=@("Tyrell","KingsGuard");              Desc="Loras Tyrell - Knight of Flowers";            City="Highgarden" }
    @{ Sam="mace.tyrell";       First="Mace";      Last="Tyrell";     Pass="highgarden";         OU="OU=Reach,$domainDN";       Groups=@("Tyrell","Small Council");           Desc="Mace Tyrell - Lord of Highgarden";            City="Highgarden" }
    @{ Sam="randyll.tarly";     First="Randyll";   Last="Tarly";      Pass="Heartsbane!1";       OU="OU=Reach,$domainDN";       Groups=@("Tyrell");                           Desc="Randyll Tarly - Lord of Horn Hill";           City="Horn Hill" }
    @{ Sam="dickon.tarly";      First="Dickon";    Last="Tarly";      Pass="NotSam123";          OU="OU=Reach,$domainDN";       Groups=@("Tyrell");                           Desc="Dickon Tarly";                                City="Horn Hill" }
    @{ Sam="garlan.tyrell";     First="Garlan";    Last="Tyrell";     Pass="Gallant!";           OU="OU=Reach,$domainDN";       Groups=@("Tyrell");                           Desc="Garlan Tyrell - The Gallant";                 City="Highgarden" }
    # IronIslands
    @{ Sam="balon.greyjoy";     First="Balon";     Last="Greyjoy";    Pass="W3D0NotSow!";        OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Balon Greyjoy - Lord of the Iron Islands";   City="Pyke" }
    @{ Sam="theon.greyjoy";     First="Theon";     Last="Greyjoy";    Pass="reek2023";           OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Theon Greyjoy";                               City="Pyke" }
    @{ Sam="yara.greyjoy";      First="Yara";      Last="Greyjoy";    Pass="Ironb0rn!";          OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Yara Greyjoy - Captain";                      City="Pyke" }
    @{ Sam="euron.greyjoy";     First="Euron";     Last="Greyjoy";    Pass="S1lenceShip";        OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Euron Greyjoy - Crow's Eye";                  City="Pyke" }
    @{ Sam="victarion.greyjoy"; First="Victarion"; Last="Greyjoy";    Pass="IronFl33t";          OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Victarion Greyjoy - Iron Captain";            City="Pyke" }
    @{ Sam="aeron.greyjoy";     First="Aeron";     Last="Greyjoy";    Pass="DrownedG0d";         OU="OU=IronIslands,$domainDN"; Groups=@("Greyjoy");                          Desc="Aeron Greyjoy - Damphair";                    City="Pyke" }
    # Riverlands
    @{ Sam="edmure.tully";      First="Edmure";    Last="Tully";      Pass="Riv3rrun!";          OU="OU=Riverlands,$domainDN";  Groups=@("Tully");                            Desc="Edmure Tully - Lord of Riverrun";             City="Riverrun" }
    @{ Sam="brynden.tully";     First="Brynden";   Last="Tully";      Pass="Blackf1sh!";         OU="OU=Riverlands,$domainDN";  Groups=@("Tully");                            Desc="Brynden Tully - The Blackfish";               City="Riverrun" }
    @{ Sam="walder.frey";       First="Walder";    Last="Frey";       Pass="hehehe123";          OU="OU=Riverlands,$domainDN";  Groups=@("Frey");                             Desc="Walder Frey - The Late Lord Frey";            City="The Twins" }
    @{ Sam="lothar.frey";       First="Lothar";    Last="Frey";       Pass="LameLothar1";        OU="OU=Riverlands,$domainDN";  Groups=@("Frey");                             Desc="Lothar Frey - Lame Lothar";                   City="The Twins" }
    @{ Sam="roslin.frey";       First="Roslin";    Last="Frey";       Pass="edmure4ever";        OU="OU=Riverlands,$domainDN";  Groups=@("Frey","Tully");                     Desc="Roslin Frey - Wife of Edmure";                City="The Twins" }
    @{ Sam="stevron.frey";      First="Stevron";   Last="Frey";       Pass="FrstBorn1";          OU="OU=Riverlands,$domainDN";  Groups=@("Frey");                             Desc="Stevron Frey - Eldest Son";                   City="The Twins" }
    @{ Sam="olyvar.frey";       First="Olyvar";    Last="Frey";       Pass="squire2024";         OU="OU=Riverlands,$domainDN";  Groups=@("Frey");                             Desc="Olyvar Frey - Squire to Robb Stark";         City="The Twins" }
    # Stormlands
    @{ Sam="davos.seaworth";    First="Davos";     Last="Seaworth";   Pass="On1onKn1ght!";       OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard","Small Council");       Desc="Davos Seaworth - The Onion Knight";           City="Cape Wrath" }
    @{ Sam="gendry.baratheon";  First="Gendry";    Last="Baratheon";  Pass="Hamm3r_Time";        OU="OU=Stormlands,$domainDN";  Groups=@("Baratheon","Stormguard");           Desc="Gendry Baratheon - Legitimised bastard";      City="Storm's End" }
    @{ Sam="brienne.tarth";     First="Brienne";   Last="Tarth";      Pass="Oath_K33per!";       OU="OU=Stormlands,$domainDN";  Groups=@("KingsGuard","Stormguard");          Desc="Brienne of Tarth";                            City="Evenfall Hall" }
    @{ Sam="beric.dondarrion";  First="Beric";     Last="Dondarrion"; Pass="L1ghtBr1ng3r";       OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard");                       Desc="Beric Dondarrion - Lord of Blackhaven";       City="Blackhaven" }
    @{ Sam="podrick.payne";     First="Podrick";   Last="Payne";      Pass="loyalsquire";        OU="OU=Stormlands,$domainDN";  Groups=@("Stormguard");                       Desc="Podrick Payne - Squire";                      City="Storm's End" }
    @{ Sam="selyse.baratheon";  First="Selyse";    Last="Baratheon";  Pass="RhLorBurns";         OU="OU=Stormlands,$domainDN";  Groups=@("Baratheon");                        Desc="Selyse Baratheon - Wife of Stannis";          City="Dragonstone" }
)

foreach ($u in $skUsers) {
    try {
        $secPass = ConvertTo-SecureString $u.Pass -AsPlainText -Force
        New-ADUser -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$domain" `
            -Name "$($u.First) $($u.Last)" -GivenName $u.First -Surname $u.Last `
            -Description $u.Desc -City $u.City -Path $u.OU `
            -AccountPassword $secPass -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
        foreach ($grp in $u.Groups) { Add-ADGroupMember -Identity $grp -Members $u.Sam }
        Write-Host "[+] $($u.Sam)" -ForegroundColor Green
    } catch { Write-Host "[=] $($u.Sam) (exists or error)" -ForegroundColor DarkGray }
}

# SPNs
@("loras.tyrell","HTTP/highgarden.sevenkingdoms.local"),
("theon.greyjoy","HTTP/pyke.sevenkingdoms.local"),
("brienne.tarth","HTTP/evenfall.sevenkingdoms.local"),
("davos.seaworth","HTTP/capewrath.sevenkingdoms.local") | ForEach-Object {
    Set-ADUser -Identity $_[0] -ServicePrincipalNames @{Add=$_[1]}
    Write-Host "[+] SPN: $($_[0]) -> $($_[1])" -ForegroundColor Green
}

# AS-REP Roastable
"trystane.martell","podrick.payne","olyvar.frey","dickon.tarly" | ForEach-Object {
    Set-ADAccountControl -Identity $_ -DoesNotRequirePreAuth $true
    Write-Host "[+] AS-REP: $_" -ForegroundColor Green
}

Write-Host "[*] STEP 1 complete: $($skUsers.Count) users in sevenkingdoms.local`n" -ForegroundColor Cyan

# ================================================================
# STEP 2: Create users on DC02 (winterfell) via Invoke-Command
# ================================================================
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "STEP 2/5: north.sevenkingdoms.local users (DC02 - remote)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Invoke-Command -ComputerName winterfell -Credential $credNorth -ScriptBlock {
    Import-Module ActiveDirectory
    $domainDN = "DC=north,DC=sevenkingdoms,DC=local"
    $domain = "north.sevenkingdoms.local"

    # OUs
    "Wildlings","Bolton","Manderly" | ForEach-Object {
        try { New-ADOrganizationalUnit -Name $_ -Path $domainDN -ProtectedFromAccidentalDeletion $false; Write-Host "[+] OU: $_" -ForegroundColor Green }
        catch { Write-Host "[=] OU exists: $_" -ForegroundColor DarkGray }
    }

    # Groups
    @(
        @{ Name="Freefolk";  Path="OU=Wildlings,$domainDN" },
        @{ Name="Bolton";    Path="OU=Bolton,$domainDN" },
        @{ Name="Manderly";  Path="OU=Manderly,$domainDN" },
        @{ Name="Reed";      Path="CN=Users,$domainDN" }
    ) | ForEach-Object {
        try { New-ADGroup -Name $_.Name -GroupScope Global -GroupCategory Security -Path $_.Path; Write-Host "[+] Group: $($_.Name)" -ForegroundColor Green }
        catch { Write-Host "[=] Group exists: $($_.Name)" -ForegroundColor DarkGray }
    }

    $users = @(
        @{ Sam="tormund.giantsbane"; First="Tormund"; Last="Giantsbane"; Pass="giantsmilk!";        OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");             Desc="Tormund Giantsbane"; City="Beyond the Wall" }
        @{ Sam="mance.rayder";       First="Mance";   Last="Rayder";     Pass="K1ngBey0ndTheWall";  OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");             Desc="Mance Rayder - King-Beyond-the-Wall"; City="Beyond the Wall" }
        @{ Sam="ygritte";            First="Ygritte"; Last="Wildling";   Pass="youknownothing";     OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");             Desc="Ygritte"; City="Beyond the Wall" }
        @{ Sam="craster";            First="Craster"; Last="Wildling";   Pass="k33p2024";           OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");             Desc="Craster"; City="Craster's Keep" }
        @{ Sam="styr";               First="Styr";    Last="Thenn";      Pass="Th3nnW4rr1or";       OU="OU=Wildlings,$domainDN"; Groups=@("Freefolk");             Desc="Styr - Magnar of Thenns"; City="Beyond the Wall" }
        @{ Sam="roose.bolton";       First="Roose";   Last="Bolton";     Pass="0urBladesAreSharp!"; OU="OU=Bolton,$domainDN";    Groups=@("Bolton");               Desc="Roose Bolton - Lord of the Dreadfort"; City="Dreadfort" }
        @{ Sam="ramsay.bolton";      First="Ramsay";  Last="Bolton";     Pass="Ree3k_Ree3k";        OU="OU=Bolton,$domainDN";    Groups=@("Bolton");               Desc="Ramsay Bolton"; City="Dreadfort" }
        @{ Sam="locke";              First="Locke";   Last="Bolton";     Pass="hunt3rsCatch";        OU="OU=Bolton,$domainDN";    Groups=@("Bolton");               Desc="Locke - Bolton man-at-arms"; City="Dreadfort" }
        @{ Sam="wyman.manderly";     First="Wyman";   Last="Manderly";   Pass="Th3N0rthR3memb3rs!"; OU="OU=Manderly,$domainDN";  Groups=@("Manderly","Stark");     Desc="Wyman Manderly"; City="White Harbor" }
        @{ Sam="wylis.manderly";     First="Wylis";   Last="Manderly";   Pass="WH4rb0r2024";        OU="OU=Manderly,$domainDN";  Groups=@("Manderly");             Desc="Wylis Manderly"; City="White Harbor" }
        @{ Sam="meera.reed";         First="Meera";   Last="Reed";       Pass="Crannog!23";          OU="CN=Users,$domainDN";     Groups=@("Reed","Stark");         Desc="Meera Reed"; City="Greywater Watch" }
        @{ Sam="jojen.reed";         First="Jojen";   Last="Reed";       Pass="Gr33nDr3ams";         OU="CN=Users,$domainDN";     Groups=@("Reed");                 Desc="Jojen Reed"; City="Greywater Watch" }
        @{ Sam="benjen.stark";       First="Benjen";  Last="Stark";      Pass="F1rstRang3r!";        OU="CN=Users,$domainDN";     Groups=@("Stark","Night Watch");  Desc="Benjen Stark - First Ranger"; City="Castle Black" }
        @{ Sam="lyanna.mormont";     First="Lyanna";  Last="Mormont";    Pass="B3arIsland!";         OU="CN=Users,$domainDN";     Groups=@("Mormont","Stark");      Desc="Lyanna Mormont"; City="Bear Island" }
    )

    foreach ($u in $users) {
        try {
            $secPass = ConvertTo-SecureString $u.Pass -AsPlainText -Force
            New-ADUser -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$domain" `
                -Name "$($u.First) $($u.Last)" -GivenName $u.First -Surname $u.Last `
                -Description $u.Desc -City $u.City -Path $u.OU `
                -AccountPassword $secPass -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
            foreach ($grp in $u.Groups) { Add-ADGroupMember -Identity $grp -Members $u.Sam }
            Write-Host "[+] $($u.Sam)" -ForegroundColor Green
        } catch { Write-Host "[=] $($u.Sam) (exists or error)" -ForegroundColor DarkGray }
    }

    # SPNs
    Set-ADUser -Identity "tormund.giantsbane" -ServicePrincipalNames @{Add="HTTP/wildlings.north.sevenkingdoms.local"}
    Set-ADUser -Identity "roose.bolton" -ServicePrincipalNames @{Add="HTTP/dreadfort.north.sevenkingdoms.local"}
    # AS-REP
    Set-ADAccountControl -Identity "craster" -DoesNotRequirePreAuth $true
    Set-ADAccountControl -Identity "ramsay.bolton" -DoesNotRequirePreAuth $true

    Write-Host "[*] north.sevenkingdoms.local complete: $($users.Count) users" -ForegroundColor Cyan
}

Write-Host "[*] STEP 2 complete`n" -ForegroundColor Cyan

# ================================================================
# STEP 3: Create users on DC03 (meereen) via Invoke-Command
# ================================================================
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "STEP 3/5: essos.local users (DC03 - remote)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Invoke-Command -ComputerName meereen -Credential $credEssos -ScriptBlock {
    Import-Module ActiveDirectory
    $domainDN = "DC=essos,DC=local"
    $domain = "essos.local"

    # OUs
    "Meereen","Pentos","Braavos","Volantis" | ForEach-Object {
        try { New-ADOrganizationalUnit -Name $_ -Path $domainDN -ProtectedFromAccidentalDeletion $false; Write-Host "[+] OU: $_" -ForegroundColor Green }
        catch { Write-Host "[=] OU exists: $_" -ForegroundColor DarkGray }
    }

    # Groups
    @(
        @{ Name="Unsullied";   Path="OU=Meereen,$domainDN" },
        @{ Name="SecondSons";  Path="OU=Meereen,$domainDN" },
        @{ Name="Masters";     Path="OU=Meereen,$domainDN" },
        @{ Name="FacelessMen"; Path="OU=Braavos,$domainDN" },
        @{ Name="Merchants";   Path="OU=Pentos,$domainDN" }
    ) | ForEach-Object {
        try { New-ADGroup -Name $_.Name -GroupScope Global -GroupCategory Security -Path $_.Path; Write-Host "[+] Group: $($_.Name)" -ForegroundColor Green }
        catch { Write-Host "[=] Group exists: $($_.Name)" -ForegroundColor DarkGray }
    }

    $users = @(
        @{ Sam="grey.worm";        First="Grey";      Last="Worm";      Pass="Unsull13d!";      OU="OU=Meereen,$domainDN";  Groups=@("Unsullied","Targaryen");  Desc="Grey Worm - Commander of the Unsullied"; City="Meereen" }
        @{ Sam="daario.naharis";   First="Daario";    Last="Naharis";   Pass="Sw0rdAndCharm";   OU="OU=Meereen,$domainDN";  Groups=@("SecondSons");             Desc="Daario Naharis - Captain of the Second Sons"; City="Meereen" }
        @{ Sam="hizdahr.loraq";    First="Hizdahr";   Last="Loraq";     Pass="N0bleBlood";      OU="OU=Meereen,$domainDN";  Groups=@("Masters");                Desc="Hizdahr zo Loraq"; City="Meereen" }
        @{ Sam="barristan.selmy";  First="Barristan"; Last="Selmy";     Pass="B0ldBarr1stan!";  OU="OU=Meereen,$domainDN";  Groups=@("Targaryen");              Desc="Barristan Selmy - Barristan the Bold"; City="Meereen" }
        @{ Sam="tyrion.essos";     First="Tyrion";    Last="Lannister"; Pass="IdrinkAndIkn0w";  OU="OU=Meereen,$domainDN";  Groups=@("Targaryen");              Desc="Tyrion Lannister - Hand of the Queen (Essos)"; City="Meereen" }
        @{ Sam="illyrio.mopatis";  First="Illyrio";   Last="Mopatis";   Pass="Ch33seAndW1ne";   OU="OU=Pentos,$domainDN";   Groups=@("Merchants");              Desc="Illyrio Mopatis - Magister of Pentos"; City="Pentos" }
        @{ Sam="varys.essos";      First="Varys";     Last="Spider";    Pass="Wh1spers&B1rds";  OU="OU=Pentos,$domainDN";   Groups=@("Merchants");              Desc="Varys - The Spider (Essos identity)"; City="Pentos" }
        @{ Sam="kinvara";          First="Kinvara";   Last="Volantis";  Pass="L0rdOfL1ght!";    OU="OU=Volantis,$domainDN"; Groups=@();                         Desc="Kinvara - Red Priestess"; City="Volantis" }
        @{ Sam="syrio.forel";      First="Syrio";     Last="Forel";     Pass="N0tToday!";       OU="OU=Braavos,$domainDN";  Groups=@("FacelessMen");            Desc="Syrio Forel - First Sword of Braavos"; City="Braavos" }
        @{ Sam="jaqen.hghar";      First="Jaqen";     Last="Hghar";     Pass="V4larM0rghul1s";  OU="OU=Braavos,$domainDN";  Groups=@("FacelessMen");            Desc="Jaqen H'ghar - A man has no name"; City="Braavos" }
        @{ Sam="tycho.nestoris";   First="Tycho";     Last="Nestoris";  Pass="Ir0nBank_Pays";   OU="OU=Braavos,$domainDN";  Groups=@("Merchants");              Desc="Tycho Nestoris - Iron Bank"; City="Braavos" }
        @{ Sam="izembaro";         First="Izembaro";  Last="Actor";     Pass="theatre2024";     OU="OU=Braavos,$domainDN";  Groups=@();                         Desc="Izembaro - Theatre troupe leader"; City="Braavos" }
    )

    foreach ($u in $users) {
        try {
            $secPass = ConvertTo-SecureString $u.Pass -AsPlainText -Force
            New-ADUser -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@$domain" `
                -Name "$($u.First) $($u.Last)" -GivenName $u.First -Surname $u.Last `
                -Description $u.Desc -City $u.City -Path $u.OU `
                -AccountPassword $secPass -Enabled $true -PasswordNeverExpires $true -ChangePasswordAtLogon $false
            foreach ($grp in $u.Groups) { Add-ADGroupMember -Identity $grp -Members $u.Sam }
            Write-Host "[+] $($u.Sam)" -ForegroundColor Green
        } catch { Write-Host "[=] $($u.Sam) (exists or error)" -ForegroundColor DarkGray }
    }

    # SPNs
    Set-ADUser -Identity "tycho.nestoris" -ServicePrincipalNames @{Add="HTTP/ironbank.essos.local"}
    Set-ADUser -Identity "daario.naharis" -ServicePrincipalNames @{Add="HTTP/secondsons.essos.local"}
    # AS-REP
    Set-ADAccountControl -Identity "izembaro" -DoesNotRequirePreAuth $true
    Set-ADAccountControl -Identity "hizdahr.loraq" -DoesNotRequirePreAuth $true

    Write-Host "[*] essos.local complete: $($users.Count) users" -ForegroundColor Cyan
}

Write-Host "[*] STEP 3 complete`n" -ForegroundColor Cyan

# ================================================================
# STEP 4: File shares and MSSQL on SRV02 (castelblack) via Invoke-Command
# ================================================================
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "STEP 4/5: Shares & MSSQL (SRV02 - remote)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Invoke-Command -ComputerName castelblack -Credential $credNorth -ScriptBlock {
    # Shares
    $shares = @(
        @{ Name="Dorne";      Path="C:\shares\dorne";      Full="SEVENKINGDOMS\Martell";                              Read="SEVENKINGDOMS\Domain Users" }
        @{ Name="IronIslands"; Path="C:\shares\ironislands"; Full="SEVENKINGDOMS\Greyjoy";                             Read="SEVENKINGDOMS\Domain Users" }
        @{ Name="Reach";      Path="C:\shares\reach";       Full="SEVENKINGDOMS\Tyrell";                               Read="SEVENKINGDOMS\Domain Users" }
        @{ Name="Riverlands"; Path="C:\shares\riverlands";  Full="SEVENKINGDOMS\Tully","SEVENKINGDOMS\Frey";           Read="SEVENKINGDOMS\Domain Users" }
        @{ Name="Finance";    Path="C:\shares\finance";     Full="SEVENKINGDOMS\Small Council";                        Read="SEVENKINGDOMS\Domain Users" }
        @{ Name="HR";         Path="C:\shares\hr";          Full="SEVENKINGDOMS\Small Council";                        Read="SEVENKINGDOMS\Domain Users","NORTH\Domain Users" }
    )

    foreach ($s in $shares) {
        New-Item -ItemType Directory -Path $s.Path -Force | Out-Null
        try {
            New-SmbShare -Name $s.Name -Path $s.Path -FullAccess $s.Full -ReadAccess $s.Read -ErrorAction Stop
            Write-Host "[+] Share: \\castelblack\$($s.Name)" -ForegroundColor Green
        } catch { Write-Host "[=] Share exists: $($s.Name)" -ForegroundColor DarkGray }
    }

    # Loot files
    @{
        "C:\shares\finance\budget_q4_2025.xlsx"       = "[Budget spreadsheet - accounts payable]"
        "C:\shares\finance\vendor_payments.csv"        = "vendor,amount,account`nIron Bank,50000,IB-2024-8891`nHighgarden Supplies,12000,HG-2024-3321"
        "C:\shares\finance\wire_transfer_template.txt" = "Wire Transfer Auth`nFrom: Treasury`nTo: [RECIPIENT]`nAmount: [AMOUNT]`nAuth Officer: Mace Tyrell"
        "C:\shares\hr\new_starters_2025.txt"           = "New starters Q1:`n- Gendry Baratheon`n- Roslin Frey`nDefault password: FirstnameYear! (change on first login)"
        "C:\shares\hr\salary_bands.txt"                = "Band A (Lords): 100k+`nBand B (Knights): 60-100k`nBand C (Squires): 30-60k"
        "C:\shares\dorne\trade_routes.txt"             = "Sunspear to King's Landing: 5 days`nContact: oberyn.martell@sevenkingdoms.local"
        "C:\shares\ironislands\fleet_manifest.txt"     = "Ship: Silence (Euron)`nShip: Iron Victory (Victarion)`nDock codes: PYKE-2024-IRON"
        "C:\shares\reach\harvest_report.txt"           = "Wheat: 450 tons`nWine: 80 barrels`nApproved by: Mace Tyrell"
        "C:\shares\riverlands\bridge_tolls.txt"        = "The Twins toll schedule:`nPeasant: 1 silver`nLord: A marriage alliance`nCollector: Walder Frey"
    }.GetEnumerator() | ForEach-Object { Set-Content -Path $_.Key -Value $_.Value -Force }
    Write-Host "[+] Dropped 9 loot files across shares" -ForegroundColor Green

    # MSSQL
    $sql = @"
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\olenna.tyrell')
    CREATE LOGIN [SEVENKINGDOMS\olenna.tyrell] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\doran.martell')
    CREATE LOGIN [SEVENKINGDOMS\doran.martell] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\davos.seaworth')
    CREATE LOGIN [SEVENKINGDOMS\davos.seaworth] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\walder.frey')
    CREATE LOGIN [SEVENKINGDOMS\walder.frey] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\theon.greyjoy')
    CREATE LOGIN [SEVENKINGDOMS\theon.greyjoy] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SEVENKINGDOMS\brienne.tarth')
    CREATE LOGIN [SEVENKINGDOMS\brienne.tarth] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'NORTH\wyman.manderly')
    CREATE LOGIN [NORTH\wyman.manderly] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'NORTH\roose.bolton')
    CREATE LOGIN [NORTH\roose.bolton] FROM WINDOWS;
ALTER SERVER ROLE sysadmin ADD MEMBER [SEVENKINGDOMS\brienne.tarth];
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'finance_reports')
    CREATE LOGIN finance_reports WITH PASSWORD = 'reports2024', CHECK_POLICY = OFF;
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'SEVENKINGDOMS\olenna.tyrell')
    CREATE USER [SEVENKINGDOMS\olenna.tyrell] FOR LOGIN [SEVENKINGDOMS\olenna.tyrell];
ALTER ROLE db_datareader ADD MEMBER [SEVENKINGDOMS\olenna.tyrell];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'SEVENKINGDOMS\walder.frey')
    CREATE USER [SEVENKINGDOMS\walder.frey] FOR LOGIN [SEVENKINGDOMS\walder.frey];
ALTER ROLE db_datareader ADD MEMBER [SEVENKINGDOMS\walder.frey];
GRANT IMPERSONATE ON LOGIN::[SEVENKINGDOMS\walder.frey] TO [SEVENKINGDOMS\theon.greyjoy];
PRINT 'MSSQL expansion complete';
"@
    try {
        Invoke-Sqlcmd -Query $sql -ServerInstance "localhost" -TrustServerCertificate
        Write-Host "[+] MSSQL logins and permissions configured" -ForegroundColor Green
    } catch {
        $sql | Out-File "C:\setup\mssql_expansion.sql" -Encoding UTF8
        & sqlcmd -S localhost -E -i "C:\setup\mssql_expansion.sql"
    }

    Write-Host "[*] Shares and MSSQL complete" -ForegroundColor Cyan
}

Write-Host "[*] STEP 4 complete`n" -ForegroundColor Cyan

# ================================================================
# STEP 5: Exchange mailboxes + BEC on SRV01 (the-eyrie) via Invoke-Command
# ================================================================
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "STEP 5/5: Exchange mailboxes & BEC (SRV01 - remote)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Invoke-Command -ComputerName the-eyrie -Credential $credSK -ScriptBlock {
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

    # Enable mailboxes for all non-mailbox users
    $excluded = @("administrator","ansible","goadmin","vagrant","krbtgt","Guest")
    $newUsers = Get-User -RecipientTypeDetails User -ResultSize Unlimited | Where-Object {
        $_.RecipientTypeDetails -ne 'MailboxUser' -and
        $excluded -notcontains $_.SamAccountName -and
        -not $_.SamAccountName.EndsWith('$')
    }

    $count = 0
    foreach ($user in $newUsers) {
        try {
            Enable-Mailbox -Identity $user.SamAccountName
            Set-MailboxRegionalConfiguration -Identity $user.SamAccountName -Language en-US -TimeZone "Romance Standard Time" -ErrorAction SilentlyContinue
            Write-Host "[+] Mailbox: $($user.SamAccountName)" -ForegroundColor Green
            $count++
        } catch { Write-Host "[!] Mailbox failed: $($user.SamAccountName)" -ForegroundColor Red }
    }
    Write-Host "[*] Enabled $count new mailboxes" -ForegroundColor Cyan

    Start-Sleep -Seconds 30

    # BEC 1: Exec mail forwarding (internal)
    try {
        Set-Mailbox -Identity "doran.martell" -ForwardingAddress "ellaria.sand" -DeliverToMailboxAndForward $true
        Write-Host "[+] BEC1: doran.martell -> ellaria.sand (forwarding)" -ForegroundColor Green
    } catch { Write-Host "[!] BEC1 failed: $_" -ForegroundColor Red }

    # BEC 2: Hidden inbox rule (finance keywords)
    try {
        New-InboxRule -Mailbox "olenna.tyrell" -Name "Archive Finance" `
            -SubjectContainsWords @("payment","invoice","wire","transfer","bank","budget") `
            -ForwardTo "walder.frey" -MarkAsRead $true -StopProcessingRules $false
        Write-Host "[+] BEC2: olenna.tyrell inbox rule -> walder.frey" -ForegroundColor Green
    } catch { Write-Host "[!] BEC2 failed: $_" -ForegroundColor Red }

    # BEC 3: Full mail redirect (altRecipient)
    try {
        Set-Mailbox -Identity "mace.tyrell" -ForwardingAddress "margaery.tyrell" -DeliverToMailboxAndForward $false
        Write-Host "[+] BEC3: mace.tyrell ALL mail -> margaery.tyrell" -ForegroundColor Green
    } catch { Write-Host "[!] BEC3 failed: $_" -ForegroundColor Red }

    # BEC 4: External SMTP forwarding
    try {
        Set-Mailbox -Identity "walder.frey" -ForwardingSMTPAddress "walder.frey@external-twins.com" -DeliverToMailboxAndForward $true
        Write-Host "[+] BEC4: walder.frey -> external-twins.com" -ForegroundColor Green
    } catch { Write-Host "[!] BEC4 failed: $_" -ForegroundColor Red }

    # BEC 5: Hidden mailbox delegation
    try {
        Add-MailboxPermission -Identity "balon.greyjoy" -User "euron.greyjoy" -AccessRights FullAccess -AutoMapping $false
        Write-Host "[+] BEC5: euron.greyjoy FullAccess to balon.greyjoy (hidden)" -ForegroundColor Green
    } catch { Write-Host "[!] BEC5 failed: $_" -ForegroundColor Red }

    # BEC 6: Send-As impersonation
    try {
        Add-ADPermission -Identity "roose.bolton" -User "NORTH\ramsay.bolton" -AccessRights ExtendedRight -ExtendedRights "Send As"
        Write-Host "[+] BEC6: ramsay.bolton Send-As roose.bolton" -ForegroundColor Green
    } catch { Write-Host "[!] BEC6 failed: $_" -ForegroundColor Red }

    # Seed emails
    $emails = @(
        @{ From="cersei.lannister@sevenkingdoms.local";  To="doran.martell@sevenkingdoms.local";   Subject="RE: Alliance Terms";              Body="Doran, the terms are acceptable. Proceed. -Cersei" }
        @{ From="olenna.tyrell@sevenkingdoms.local";     To="mace.tyrell@sevenkingdoms.local";     Subject="Q4 Budget wire transfer approval"; Body="Mace, approve the wire transfer of 50000 gold dragons to Iron Bank. Account: IB-2024-8891." }
        @{ From="davos.seaworth@sevenkingdoms.local";    To="stannis.baratheon@sevenkingdoms.local"; Subject="Invoice from Iron Bank";          Body="My Lord, attached is the invoice. Payment due in 30 days." }
        @{ From="tywin.lannister@sevenkingdoms.local";   To="cersei.lannister@sevenkingdoms.local"; Subject="RE: Payroll access";               Body="Cersei, payroll access granted. Password is in the HR share." }
        @{ From="walder.frey@sevenkingdoms.local";       To="lothar.frey@sevenkingdoms.local";     Subject="Wedding arrangements";             Body="Lothar, ensure the musicians are briefed. The Rains of Castamere." }
        @{ From="olenna.tyrell@sevenkingdoms.local";     To="margaery.tyrell@sevenkingdoms.local";  Subject="RE: Payment schedule";             Body="Margaery, the payment schedule for next quarter. Keep this between us." }
        @{ From="balon.greyjoy@sevenkingdoms.local";     To="yara.greyjoy@sevenkingdoms.local";    Subject="Fleet orders";                     Body="Yara, take 30 ships. Dock codes: PYKE-2024-IRON." }
        @{ From="roose.bolton@north.sevenkingdoms.local"; To="ramsay.bolton@north.sevenkingdoms.local"; Subject="Dreadfort garrison";           Body="Ramsay, the garrison passwords are Flayed2024. Do not share." }
    )

    foreach ($e in $emails) {
        try {
            Send-MailMessage -From $e.From -To $e.To -Subject $e.Subject -Body $e.Body -SmtpServer "localhost"
            Write-Host "[+] Email: $($e.From) -> $($e.To)" -ForegroundColor Green
        } catch { Write-Host "[!] Email failed: $($e.Subject)" -ForegroundColor Yellow }
    }

    Write-Host "[*] Exchange and BEC setup complete" -ForegroundColor Cyan
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "ALL STEPS COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Users created: ~60 across 3 domains"
Write-Host "Shares: 6 with loot files"
Write-Host "MSSQL logins: 8 + 1 weak SQL auth"
Write-Host "BEC scenarios: 6"
Write-Host "Seed emails: 8"
Write-Host "`nRun from DC01 (kingslanding). All remote steps used Invoke-Command." -ForegroundColor Cyan
