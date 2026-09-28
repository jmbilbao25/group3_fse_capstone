# ==============================================================================
# Launch Spring Boot Microservices with Datadog APM Java Tracer
# ==============================================================================

param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("gateway-service", "account-service", "ledger-mutation-engine", "notification-service")]
    [string]$Service = "gateway-service"
)

$AgentJar = "C:\datadog\dd-java-agent.jar"
if (-not (Test-Path $AgentJar)) {
    $AgentJar = Join-Path $PSScriptRoot "..\infrastructure\datadog\dd-java-agent.jar"
}

Write-Host ">>> Starting $Service with Datadog APM Agent..." -ForegroundColor Cyan
Write-Host "    Tracer Jar: $AgentJar" -ForegroundColor Gray
Write-Host "    APM Target: localhost:8126" -ForegroundColor Gray
Write-Host "    Environment: local" -ForegroundColor Gray

$JvmArgs = "-javaagent:`"$AgentJar`" -Ddd.service=$Service -Ddd.env=local -Ddd.version=1.0.0 -Ddd.logs.injection=true -Ddd.agent.host=localhost -Ddd.agent.port=8126 -Ddd.trace.analytics.enabled=true"

Set-Location $PSScriptRoot
& .\mvnw.cmd spring-boot:run -pl $Service -Dspring-boot.run.jvmArguments="$JvmArgs"
