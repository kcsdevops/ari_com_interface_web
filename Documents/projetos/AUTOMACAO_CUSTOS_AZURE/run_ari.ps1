# Script para executar o ARI usando PowerShell 7
param(
    [string]$TenantID = "",
    [string]$SubscriptionIDs = "",
    [switch]$IncludeTags = $true,
    [switch]$IncludeCosts = $true,
    [string]$ReportDir = ""
)

# Definir timeout para operações (2 horas)
$maxTimeout = 7200

# Verificar se está sendo executado no PowerShell 7
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Este script requer PowerShell 7 ou superior. Executando com PowerShell 7..." -ForegroundColor Yellow
    
    # Construir a linha de comando com os mesmos parâmetros
    $arguments = @("-File", $PSCommandPath)
    if ($TenantID) { $arguments += "-TenantID"; $arguments += $TenantID }
    if ($SubscriptionIDs) { $arguments += "-SubscriptionIDs"; $arguments += $SubscriptionIDs }
    if ($IncludeTags) { $arguments += "-IncludeTags" }
    if ($IncludeCosts) { $arguments += "-IncludeCosts" }
    if ($ReportDir) { $arguments += "-ReportDir"; $arguments += $ReportDir }
    
    # Reexecutar o script com pwsh.exe (PowerShell 7)
    & pwsh.exe $arguments
    exit
}

# Criar diretório de saída se não existir
if (-not $ReportDir) {
    $ReportDir = "$PSScriptRoot\data\ari_output"
}

if (-not (Test-Path -Path $ReportDir)) {
    New-Item -Path $ReportDir -ItemType Directory -Force | Out-Null
    Write-Host "Diretório de relatórios criado: $ReportDir" -ForegroundColor Green
}

# Configuração para prevenção de travamentos
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue" # Reduz a sobrecarga de UI

# Importar o módulo ARI
try {
    Import-Module -Name "$PSScriptRoot\ARI\AzureResourceInventory.psd1" -Force -ErrorAction Stop
    Write-Host "Módulo ARI importado com sucesso." -ForegroundColor Green
}
catch {
    Write-Host "Erro ao importar o módulo ARI: $_" -ForegroundColor Red
    exit 1
}

# Verificar conexão Azure
try {
    $context = Get-AzContext -ErrorAction Stop
    if (-not $context.Account) {
        Write-Host "Conectando ao Azure..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop
    }
    else {
        Write-Host "Já conectado ao Azure como: $($context.Account.Id)" -ForegroundColor Green
        Write-Host "Assinatura atual: $($context.Subscription.Name)" -ForegroundColor Green
    }
}
catch {
    Write-Host "Erro ao verificar ou estabelecer conexão com o Azure: $_" -ForegroundColor Red
    Write-Host "Tentando conectar novamente..." -ForegroundColor Yellow
    try {
        Connect-AzAccount -ErrorAction Stop
    }
    catch {
        Write-Host "Falha ao conectar ao Azure. Encerrando script: $_" -ForegroundColor Red
        exit 1
    }
}

# Executar o ARI com um job para evitar que o script trave indefinidamente
Write-Host "Iniciando execução do ARI..." -ForegroundColor Cyan

# Preparar os parâmetros para o Invoke-ARI
$ariParams = @{
    ReportDir = $ReportDir
}

# Adicionar parâmetros condicionais
if ($IncludeTags) {
    $ariParams.Add("IncludeTags", $true)
}

if ($IncludeCosts) {
    $ariParams.Add("IncludeCosts", $true)
}

if ($TenantID) {
    $ariParams.Add("TenantID", $TenantID)
}

if ($SubscriptionIDs) {
    $subscriptionList = $SubscriptionIDs -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($subscriptionList.Count -gt 0) {
        $ariParams.Add("SubscriptionID", $subscriptionList)
    }
}

Write-Host "Parâmetros do ARI: $($ariParams | ConvertTo-Json -Compress)" -ForegroundColor Cyan

try {
    $job = Start-Job -ScriptBlock {
        param($modulePath, $params)
        
        Import-Module -Name $modulePath -Force
        Invoke-ARI @params -Verbose
    } -ArgumentList "$PSScriptRoot\ARI\AzureResourceInventory.psd1", $ariParams

    # Esperar pelo job com timeout
    $jobComplete = Wait-Job -Job $job -Timeout $maxTimeout

    if ($jobComplete -eq $null) {
        Write-Host "ARI excedeu o tempo limite de $maxTimeout segundos. Forçando término..." -ForegroundColor Red
        Stop-Job -Job $job
        Remove-Job -Job $job -Force
    }
    else {
        $result = Receive-Job -Job $job
        Remove-Job -Job $job
        
        if ($result) {
            Write-Host "ARI executado com sucesso. Verifique o relatório em: $ReportDir" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "Erro durante a execução do ARI: $_" -ForegroundColor Red
}
finally {
    # Garantir que jobs não finalizados sejam removidos
    Get-Job | Where-Object { $_.Command -like "*Invoke-ARI*" -and $_.State -ne "Completed" } | Stop-Job | Remove-Job -Force
    
    Write-Host "Script finalizado!" -ForegroundColor Cyan
}
