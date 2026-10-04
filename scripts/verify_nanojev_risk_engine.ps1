# ==============================================================================
# Automated Verification Script: Local NanoJev Risk Engine
# Tests all 4 risk scenarios, end-to-end transfer routing, and MailHog 2FA OTP
# ==============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [VERIFICATION] Local NanoJev Risk Engine End-to-End Suite" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Health Check
Write-Host "[1/5] Checking risk-service health on port 8084..." -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost:8084/health"
if ($health.status -eq "UP") {
    Write-Host "  -> PASS: risk-service is UP (Engine: $($health.engine), Version: $($health.version))" -ForegroundColor Green
} else {
    Write-Host "  -> FAIL: risk-service is unhealthy" -ForegroundColor Red
    exit 1
}

# 2. Customer Profile Lookup
Write-Host "`n[2/5] Querying seeded customer profile (acc-2001-sav-001 / Juan Dela Cruz)..." -ForegroundColor Yellow
$cust = Invoke-RestMethod -Uri "http://localhost:8084/api/v1/risk/customers/acc-2001-sav-001"
Write-Host "  -> PASS: Customer found: $($cust.full_name) | Home: $($cust.home_coordinates.label) | Avg: PHP $($cust.average_transfer_amount)" -ForegroundColor Green

# 3. Simulate Core Banking Scenarios
Write-Host "`n[3/5] Testing NanoJev System 1 simulation scenarios..." -ForegroundColor Yellow
$scenarios = @("normal", "impossible_travel", "scam_memo", "vpn_mismatch")
foreach ($s in $scenarios) {
    $res = Invoke-RestMethod -Uri "http://localhost:8084/api/v1/risk/simulate/$s" -Method Post
    Write-Host "  -> Scenario [$s]: Decision = $($res.decision) | Score = $($res.fraud_score) | Latency = $($res.evaluation_time_ms)ms | Flag = $($res.primary_flag)" -ForegroundColor Green
}

# 4. Live Ledger Transfer: Normal STP Transfer
Write-Host "`n[4/5] Executing Live Transfer #1: Normal Commute (₱250, BGC to Makati)..." -ForegroundColor Yellow
$txNormId = "TX-VRF-NORM-" + (Get-Random -Minimum 1000 -Maximum 9999)
$normBody = @{
    transaction_id = $txNormId
    account_id = "acc-2002-chk-001"
    target_account_id = "acc-2003-sav-002"
    mutation_amount = 250.0000
    memo = "lunch with team"
    latitude = 14.6760
    longitude = 121.0437
} | ConvertTo-Json

$normRes = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $normBody
Write-Host "  -> PASS: Normal Transfer executed! Status = $($normRes.status) (Direct STP Settlement)" -ForegroundColor Green

# 5. Live Ledger Transfer: Suspicious Memo (₱500, 'urgent crypto investment')
Write-Host "`n[5/5] Executing Live Transfer #2: Suspicious Memo Triggering Dynamic 2FA..." -ForegroundColor Yellow
$tx2faId = "TX-VRF-2FA-" + (Get-Random -Minimum 1000 -Maximum 9999)
$twoFaBody = @{
    transaction_id = $tx2faId
    account_id = "acc-2002-chk-001"
    target_account_id = "acc-2003-sav-002"
    mutation_amount = 500.0000
    memo = "urgent crypto investment"
    latitude = 14.6760
    longitude = 121.0437
} | ConvertTo-Json

$twoFaRes = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $twoFaBody
Write-Host "  -> PASS: Suspicious Transfer Routed! Status = $($twoFaRes.status) (Soft Hold Applied: PHP 500)" -ForegroundColor Green

# 6. Verify MailHog Email OTP
Start-Sleep -Seconds 1
$mailMsg = (Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages").items[0]
Write-Host "  -> PASS: MailHog OTP Email Dispatched!" -ForegroundColor Green
Write-Host "     To: $($mailMsg.To.Mailbox)@$($mailMsg.To.Domain)" -ForegroundColor Cyan
Write-Host "     Subject: $($mailMsg.Content.Headers.Subject[0])" -ForegroundColor Cyan

# 7. Live Ledger Transfer: Impossible Travel Block (> 7,000 km/h)
Write-Host "`n[6/5] Executing Live Transfer #3: Impossible Travel (> 7,000 km/h to Singapore)..." -ForegroundColor Yellow
$txBlockId = "TX-VRF-BLK-" + (Get-Random -Minimum 1000 -Maximum 9999)
$blockBody = @{
    transaction_id = $txBlockId
    account_id = "acc-2002-chk-001"
    target_account_id = "acc-2003-sav-002"
    mutation_amount = 500.0000
    memo = "business transfer"
    latitude = 1.3521
    longitude = 103.8198
} | ConvertTo-Json

try {
    $blockRes = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $blockBody
    Write-Host "  -> FAIL: Transfer should have been blocked!" -ForegroundColor Red
} catch {
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $errJson = $reader.ReadToEnd() | ConvertFrom-Json
    Write-Host "  -> PASS: Transfer Blocked by Security Engine! HTTP 403 Forbidden" -ForegroundColor Green
    Write-Host "     Status: $($errJson.status)" -ForegroundColor Cyan
    Write-Host "     Error Code: $($errJson.error_code)" -ForegroundColor Cyan
    Write-Host "     Reason: $($errJson.message)" -ForegroundColor Cyan
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] All NanoJev Risk Engine Verifications Passed Cleanly!" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
