# ==============================================================================
# Stop All FSE Core Retail Banking Microservices
# ==============================================================================

$ports = @(8080, 8081, 8082, 8083, 8084)

Write-Host "Stopping banking services on ports: $($ports -join ', ')..." -ForegroundColor Yellow

foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conns) {
        foreach ($c in $conns) {
            $pid = $c.OwningProcess
            if ($pid -gt 0) {
                Write-Host "Killing PID $pid on port $port..." -ForegroundColor Red
                Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Write-Host "All banking microservices stopped." -ForegroundColor Green
