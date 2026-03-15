# 04-setup-shares-mssql.ps1
# Run on SRV02 (castelblack) as local admin or domain admin
# Creates file shares and MSSQL logins for expanded users

# ================================================================
# FILE SHARES
# ================================================================
Write-Host "=== Creating File Shares ===" -ForegroundColor Cyan

# Dorne share
$dornePath = "C:\shares\dorne"
New-Item -ItemType Directory -Path $dornePath -Force | Out-Null
New-SmbShare -Name "Dorne" -Path $dornePath -FullAccess "SEVENKINGDOMS\Martell" -ReadAccess "SEVENKINGDOMS\Domain Users" -Description "Dorne regional share" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\Dorne" -ForegroundColor Green

# IronIslands share
$ironPath = "C:\shares\ironislands"
New-Item -ItemType Directory -Path $ironPath -Force | Out-Null
New-SmbShare -Name "IronIslands" -Path $ironPath -FullAccess "SEVENKINGDOMS\Greyjoy" -ReadAccess "SEVENKINGDOMS\Domain Users" -Description "Iron Islands regional share" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\IronIslands" -ForegroundColor Green

# Reach share
$reachPath = "C:\shares\reach"
New-Item -ItemType Directory -Path $reachPath -Force | Out-Null
New-SmbShare -Name "Reach" -Path $reachPath -FullAccess "SEVENKINGDOMS\Tyrell" -ReadAccess "SEVENKINGDOMS\Domain Users" -Description "Reach regional share" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\Reach" -ForegroundColor Green

# Riverlands share
$riverPath = "C:\shares\riverlands"
New-Item -ItemType Directory -Path $riverPath -Force | Out-Null
New-SmbShare -Name "Riverlands" -Path $riverPath -FullAccess "SEVENKINGDOMS\Tully","SEVENKINGDOMS\Frey" -ReadAccess "SEVENKINGDOMS\Domain Users" -Description "Riverlands regional share" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\Riverlands" -ForegroundColor Green

# Finance share (cross-domain, BEC target)
$financePath = "C:\shares\finance"
New-Item -ItemType Directory -Path $financePath -Force | Out-Null
New-SmbShare -Name "Finance" -Path $financePath -FullAccess "SEVENKINGDOMS\Small Council" -ChangeAccess "SEVENKINGDOMS\Tyrell","NORTH\Manderly" -ReadAccess "SEVENKINGDOMS\Domain Users" -Description "Finance documents" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\Finance" -ForegroundColor Green

# HR share
$hrPath = "C:\shares\hr"
New-Item -ItemType Directory -Path $hrPath -Force | Out-Null
New-SmbShare -Name "HR" -Path $hrPath -FullAccess "SEVENKINGDOMS\Small Council" -ReadAccess "SEVENKINGDOMS\Domain Users","NORTH\Domain Users" -Description "HR documents" -ErrorAction SilentlyContinue
Write-Host "[+] Share: \\castelblack\HR" -ForegroundColor Green

# Drop some realistic files in shares for enumeration
$files = @(
    @{ Path="$financePath\budget_q4_2025.xlsx";      Content="[Budget spreadsheet placeholder - accounts payable details]" }
    @{ Path="$financePath\vendor_payments.csv";       Content="vendor,amount,account_number`nIron Bank,50000,IB-2024-8891`nHighgarden Supplies,12000,HG-2024-3321" }
    @{ Path="$financePath\wire_transfer_template.txt"; Content="Wire Transfer Authorization`nFrom: Treasury of the Seven Kingdoms`nTo: [RECIPIENT]`nAmount: [AMOUNT]`nAuthorizing Officer: Mace Tyrell" }
    @{ Path="$hrPath\new_starters_2025.txt";          Content="New starters Q1:`n- Gendry Baratheon (Stormlands)`n- Roslin Frey (Riverlands)`nDefault password policy: FirstnameYear! (must change on first login)" }
    @{ Path="$hrPath\salary_bands.txt";               Content="Band A (Lords): 100k+`nBand B (Knights): 60-100k`nBand C (Squires): 30-60k`nBand D (Smallfolk): <30k" }
    @{ Path="$dornePath\martell_trade_routes.txt";    Content="Sunspear to Oldtown: 3 days`nSunspear to King's Landing: 5 days`nContact: oberyn.martell@sevenkingdoms.local" }
    @{ Path="$ironPath\fleet_manifest.txt";           Content="Ship: Silence (Euron)`nShip: Iron Victory (Victarion)`nShip: Black Wind (Yara)`nDock codes: PYKE-2024-IRON" }
    @{ Path="$reachPath\harvest_report.txt";          Content="Wheat: 450 tons`nBarley: 200 tons`nWine: 80 barrels`nApproved by: Mace Tyrell, Lord of Highgarden" }
    @{ Path="$riverPath\bridge_tolls.txt";            Content="The Twins toll schedule:`nPeasant: 1 silver`nMerchant: 5 gold`nLord: A marriage alliance`nCollector: Walder Frey" }
)

foreach ($f in $files) {
    Set-Content -Path $f.Path -Value $f.Content -Force
}
Write-Host "[+] Dropped $($files.Count) realistic files across shares" -ForegroundColor Green

# ================================================================
# MSSQL LOGINS
# ================================================================
Write-Host "`n=== Creating MSSQL Logins ===" -ForegroundColor Cyan

$sqlCmd = @"
-- Domain users with SQL access
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

-- Cross-domain: North users
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'NORTH\wyman.manderly')
    CREATE LOGIN [NORTH\wyman.manderly] FROM WINDOWS;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'NORTH\roose.bolton')
    CREATE LOGIN [NORTH\roose.bolton] FROM WINDOWS;

-- Over-privileged: brienne.tarth gets sysadmin (misconfiguration)
ALTER SERVER ROLE sysadmin ADD MEMBER [SEVENKINGDOMS\brienne.tarth];

-- Weak SQL auth login (for brute forcing)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'finance_reports')
    CREATE LOGIN finance_reports WITH PASSWORD = 'reports2024', CHECK_POLICY = OFF;

-- Grant db access
USE master;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'SEVENKINGDOMS\olenna.tyrell')
    CREATE USER [SEVENKINGDOMS\olenna.tyrell] FOR LOGIN [SEVENKINGDOMS\olenna.tyrell];
ALTER ROLE db_datareader ADD MEMBER [SEVENKINGDOMS\olenna.tyrell];

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'SEVENKINGDOMS\walder.frey')
    CREATE USER [SEVENKINGDOMS\walder.frey] FOR LOGIN [SEVENKINGDOMS\walder.frey];
ALTER ROLE db_datareader ADD MEMBER [SEVENKINGDOMS\walder.frey];

-- Impersonation chain: theon can impersonate walder (who has db_datareader)
GRANT IMPERSONATE ON LOGIN::[SEVENKINGDOMS\walder.frey] TO [SEVENKINGDOMS\theon.greyjoy];

PRINT 'MSSQL logins and permissions configured on castelblack';
"@

try {
    Invoke-Sqlcmd -Query $sqlCmd -ServerInstance "localhost" -TrustServerCertificate
    Write-Host "[+] MSSQL logins created on castelblack" -ForegroundColor Green
} catch {
    Write-Host "[!] MSSQL setup failed: $_" -ForegroundColor Red
    Write-Host "[*] Attempting with sqlcmd..." -ForegroundColor Yellow
    $sqlCmd | Out-File -FilePath "C:\setup\mssql_expansion.sql" -Encoding UTF8
    & sqlcmd -S localhost -E -i "C:\setup\mssql_expansion.sql"
}

Write-Host "`n[*] Shares and MSSQL expansion complete." -ForegroundColor Cyan
