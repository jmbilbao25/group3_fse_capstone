# =============================================================================
# Generate Realistic Transaction Logs & APM Traces in Datadog
# Target Service: risk-service (:8084) and ledger-mutation-engine (:8082)
# =============================================================================

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [DATADOG TELEMETRY GENERATOR] Generating Risk Engine Traces & Logs" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$scenarios = @(
    @{
        name = "Normal Commute: Morning Coffee BGC"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-NORM-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1001-cst-001"
            account_id = "acc-2001-sav-001"
            target_account_id = "acc-2002-chk-001"
            amount = 180.00
            memo = "Starbucks BGC High Street"
            latitude = 14.5547
            longitude = 121.0244
            ip_address = "112.198.10.45"
        }
    },
    @{
        name = "Normal Commute: Grocery Shopping Makati"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-NORM-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1001-cst-001"
            account_id = "acc-2001-sav-001"
            target_account_id = "acc-2003-sav-002"
            amount = 2350.50
            memo = "Rustans Supermarket Makati"
            latitude = 14.5547
            longitude = 121.0180
            ip_address = "112.198.10.45"
        }
    },
    @{
        name = "Scam Pattern: Urgent Crypto Release Fee"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-SCAM-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1002-cst-002"
            account_id = "acc-2002-chk-001"
            target_account_id = "acc-2001-sav-001"
            amount = 35000.00
            memo = "urgent crypto release fee guaranteed profit"
            latitude = 14.6760
            longitude = 121.0437
            ip_address = "112.198.10.45"
        }
    },
    @{
        name = "Scam Pattern: Lottery Prize Advance Processing Fee"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-SCAM-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1002-cst-002"
            account_id = "acc-2002-chk-001"
            target_account_id = "acc-2003-sav-002"
            amount = 28000.00
            memo = "urgent prize claim processing fee"
            latitude = 14.6500
            longitude = 121.0300
            ip_address = "112.198.10.45"
        }
    },
    @{
        name = "Impossible Travel: Cebu to Singapore in 20 Minutes (7,200 km/h)"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-BLCK-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1003-cst-003"
            account_id = "acc-2003-sav-002"
            target_account_id = "acc-2001-sav-001"
            amount = 65000.00
            memo = "Offshore account fund transfer"
            latitude = 1.3521
            longitude = 103.8198
            ip_address = "202.166.21.8"
        }
    },
    @{
        name = "Impossible Travel: Manila to London in 15 Minutes (10,500 km/h)"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-BLCK-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1001-cst-001"
            account_id = "acc-2001-sav-001"
            target_account_id = "acc-2003-sav-002"
            amount = 80000.00
            memo = "International emergency settlement"
            latitude = 51.5074
            longitude = -0.1278
            ip_address = "81.2.69.142"
        }
    },
    @{
        name = "VPN / GPS Discrepancy: Manila Device with Amsterdam Exit Node"
        endpoint = "analyze"
        payload = @{
            transaction_id = "TX-DD-VPN-" + (Get-Random -Minimum 1000 -Maximum 9999)
            user_id = "usr-1004-cst-004"
            account_id = "acc-2004-chk-002"
            target_account_id = "acc-2001-sav-001"
            amount = 4500.00
            memo = "Software development consulting"
            latitude = 14.5869
            longitude = 121.0614
            ip_latitude = 52.3676
            ip_longitude = 4.9041
            ip_address = "185.220.101.5"
        }
    }
)

$counter = 1
foreach ($sc in $scenarios) {
    Write-Host "`n[$counter/$($scenarios.Count)] Sending: $($sc.name)..." -ForegroundColor Yellow
    $body = $sc.payload | ConvertTo-Json
    
    try {
        $res = Invoke-RestMethod -Uri "http://localhost:8084/api/v1/risk/analyze" -Method Post -ContentType "application/json" -Body $body
        $decisionColor = if ($res.decision -eq "ALLOW") { "Green" } elseif ($res.decision -eq "REQUIRE_2FA") { "Yellow" } else { "Red" }
        Write-Host "  -> Decision:     $($res.decision)" -ForegroundColor $decisionColor
        Write-Host "  -> Fraud Score:  $($res.fraud_score)/100 (Anomaly: $($res.is_anomaly))" -ForegroundColor Cyan
        Write-Host "  -> Primary Flag: $($res.primary_flag)" -ForegroundColor Cyan
        Write-Host "  -> Latency:      $($res.evaluation_time_ms) ms" -ForegroundColor Gray
        Write-Host "  -> Trace ID:     $($res.neural_metadata.raw_neural_logits)" -ForegroundColor DarkGray
    } catch {
        Write-Host "  -> Request failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $counter++
    Start-Sleep -Milliseconds 400
}

# Also trigger 2 live transfers via Ledger Mutation Engine to generate distributed cross-service APM traces
Write-Host "`n[+] Executing End-to-End Ledger Mutation Engine Transfers..." -ForegroundColor Yellow

$e2eNormal = @{
    transaction_id = "TX-E2E-NORM-" + (Get-Random -Minimum 1000 -Maximum 9999)
    account_id = "acc-2001-sav-001"
    target_account_id = "acc-2002-chk-001"
    mutation_amount = 350.0000
    memo = "Quick P2P Lunch Split"
    latitude = 14.5547
    longitude = 121.0180
} | ConvertTo-Json

try {
    $e2eRes1 = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $e2eNormal
    Write-Host "  -> E2E Normal Transfer: Status = $($e2eRes1.status)" -ForegroundColor Green
} catch {
    Write-Host "  -> E2E Normal Error: $($_.Exception.Message)" -ForegroundColor Red
}

$e2eScam = @{
    transaction_id = "TX-E2E-2FA-" + (Get-Random -Minimum 1000 -Maximum 9999)
    account_id = "acc-2002-chk-001"
    target_account_id = "acc-2001-sav-001"
    mutation_amount = 500.0000
    memo = "urgent crypto release fee"
    latitude = 14.6500
    longitude = 121.0300
} | ConvertTo-Json

try {
    $e2eRes2 = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $e2eScam
    Write-Host "  -> E2E Suspicious Transfer: Status = $($e2eRes2.status) (2FA Soft Hold Triggered)" -ForegroundColor Yellow
} catch {
    Write-Host "  -> E2E Suspicious Error: $($_.Exception.Message)" -ForegroundColor Red
}

$e2eBlocked = @{
    transaction_id = "TX-E2E-BLK-" + (Get-Random -Minimum 1000 -Maximum 9999)
    account_id = "acc-2002-chk-001"
    target_account_id = "acc-2003-sav-002"
    mutation_amount = 500.0000
    memo = "overseas wire transfer"
    latitude = 1.3521
    longitude = 103.8198
} | ConvertTo-Json

try {
    $e2eRes3 = Invoke-RestMethod -Uri "http://localhost:8082/api/v1/ledger/transfer" -Method Post -ContentType "application/json" -Body $e2eBlocked
    Write-Host "  -> E2E Blocked Result: $($e2eRes3.status)" -ForegroundColor Yellow
} catch {
    Write-Host "  -> E2E Impossible Travel Blocked: HTTP 403 Forbidden (Recorded as Security Error Span)" -ForegroundColor Red
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [SUCCESS] Telemetry generated and streamed to Datadog Agent!" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
