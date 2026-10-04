# ==============================================================================
# Launch All FSE Core Retail Banking Microservices with Datadog APM Java Agent
# ==============================================================================

$AgentJar = "C:\datadog\dd-java-agent.jar"
if (-not (Test-Path $AgentJar)) {
    $AgentJar = Join-Path $PSScriptRoot "..\infrastructure\datadog\dd-java-agent.jar"
}

$services = @(
    @{ Name = "gateway-service"; Port = 8080; Jar = "gateway-service/target/gateway-service-1.0.0-SNAPSHOT.jar" },
    @{ Name = "account-service"; Port = 8081; Jar = "account-service/target/account-service-1.0.0-SNAPSHOT.jar" },
    @{ Name = "ledger-mutation-engine"; Port = 8082; Jar = "ledger-mutation-engine/target/ledger-mutation-engine-1.0.0-SNAPSHOT.jar" },
    @{ Name = "notification-service"; Port = 8083; Jar = "notification-service/target/notification-service-1.0.0-SNAPSHOT.jar" }
)

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  Starting Banking Services with Datadog APM Tracing (Target: :8126)" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

foreach ($svc in $services) {
    $jarPath = Join-Path $PSScriptRoot $svc.Jar
    if (-not (Test-Path $jarPath)) {
        Write-Warning "JAR not found: $jarPath. Run 'mvnw clean package -DskipTests' first."
        continue
    }

    $stdoutLog = Join-Path $PSScriptRoot "$($svc.Name).stdout.log"
    $stderrLog = Join-Path $PSScriptRoot "$($svc.Name).stderr.log"
    $jvmArgs = @(
        "-javaagent:$AgentJar",
        "-Ddd.service=$($svc.Name)",
        "-Ddd.env=local",
        "-Ddd.version=1.0.0",
        "-Ddd.logs.injection=true",
        "-Ddd.agent.host=localhost",
        "-Ddd.agent.port=8126",
        "-Ddd.trace.analytics.enabled=true",
        "-Dserver.port=$($svc.Port)",
        "-jar",
        "`"$jarPath`""
    )

    Write-Host "[STARTING] $($svc.Name) on port $($svc.Port)..." -ForegroundColor Yellow
    $proc = Start-Process -FilePath "java" -ArgumentList $jvmArgs -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog -PassThru -NoNewWindow
    Write-Host "  -> Process ID: $($proc.Id) (logging to $($svc.Name).stdout.log)" -ForegroundColor Green
}

# Launch Risk Engine Service (:8084)
$pythonExe = Join-Path $PSScriptRoot "risk-service\.venv\Scripts\python.exe"
if (-not (Test-Path $pythonExe)) {
    $pythonExe = Join-Path $PSScriptRoot "..\.venv\Scripts\python.exe"
}
if (-not (Test-Path $pythonExe)) {
    $pythonExe = "python"
}

$riskStdout = Join-Path $PSScriptRoot "risk-service.stdout.log"
$riskStderr = Join-Path $PSScriptRoot "risk-service.stderr.log"
$riskDir = Join-Path $PSScriptRoot "risk-service"

Write-Host "[STARTING] risk-service on port 8084..." -ForegroundColor Yellow
$riskProc = Start-Process -FilePath $pythonExe -ArgumentList "-m", "app.server" -WorkingDirectory $riskDir -RedirectStandardOutput $riskStdout -RedirectStandardError $riskStderr -PassThru -NoNewWindow
Write-Host "  -> Process ID: $($riskProc.Id) (logging to risk-service.stdout.log)" -ForegroundColor Green

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "All 5 banking services launched. Tail logs with: Get-Content <service>.log -Wait" -ForegroundColor Cyan
Write-Host "Traces available at: https://app.datadoghq.com/apm/traces" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
