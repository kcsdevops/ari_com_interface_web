# Script para criar ou atualizar recursos Azure para a aplicação ARI Web App
# Este script simplificado foca apenas na criação do Web App necessário para CD

param(
    [string]$resourceGroupName = "ari-automation-rg",
    [string]$location = "eastus",
    [string]$webAppName = "ari-automation-app",
    [string]$appServicePlanName = "ari-automation-plan",
    [ValidateSet("Free", "Shared", "Basic", "Standard", "Premium", "PremiumV2", "PremiumV3")]
    [string]$appServicePlanTier = "Basic",
    [ValidateSet("B1", "B2", "B3", "S1", "S2", "S3", "P1v2", "P2v2", "P3v2")]
    [string]$appServicePlanSize = "B1"
)

# Login to Azure (if not already logged in)
$context = Get-AzContext
if (-not $context.Account) {
    Connect-AzAccount
}

Write-Host "=== ARI Web App Direct Deployment Setup ===" -ForegroundColor Cyan

# Create Resource Group
Write-Host "Creating/Updating Resource Group: $resourceGroupName" -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# Create App Service Plan
Write-Host "Creating/Updating App Service Plan: $appServicePlanName" -ForegroundColor Cyan
$appServicePlan = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -ErrorAction SilentlyContinue
if (-not $appServicePlan) {
    $appServicePlan = New-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -Location $location -Tier $appServicePlanTier -WorkerSize $appServicePlanSize -Linux
    Write-Host "App Service Plan created successfully" -ForegroundColor Green
} else {
    Write-Host "Using existing App Service Plan: $appServicePlanName" -ForegroundColor Yellow
}

# Create Web App for Containers
Write-Host "Creating/Updating Web App: $webAppName" -ForegroundColor Cyan
$webApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -ErrorAction SilentlyContinue
if (-not $webApp) {
    $webApp = New-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -Location $location -AppServicePlan $appServicePlanName -ContainerRegistryUrl "ghcr.io" -ContainerImageName "ghcr.io/kcsdevops/ari-webapp:latest"
    Write-Host "Web App created successfully" -ForegroundColor Green
} else {
    Write-Host "Using existing Web App: $webAppName" -ForegroundColor Yellow
}

# Create AAD App Registration for GitHub Actions
Write-Host "Creating Service Principal for GitHub Actions" -ForegroundColor Cyan
$spDisplayName = "GitHub-ARI-WebApp-CD"
$sp = Get-AzADServicePrincipal -DisplayName $spDisplayName -ErrorAction SilentlyContinue
if (-not $sp) {
    $sp = New-AzADServicePrincipal -DisplayName $spDisplayName
    Write-Host "Service Principal created successfully" -ForegroundColor Green
} else {
    Write-Host "Using existing Service Principal: $spDisplayName" -ForegroundColor Yellow
}

# Create new secret for the Service Principal
$spPassword = New-AzADServicePrincipalCredential -ObjectId $sp.Id -EndDate (Get-Date).AddYears(1)

# Assign Contributor role to the service principal
New-AzRoleAssignment -ApplicationId $sp.AppId -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue | Out-Null
Write-Host "Role assignment configured" -ForegroundColor Green

# Generate random Secret Key for Flask
$secretKey = [System.Convert]::ToBase64String((New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes(32))

# Output Service Principal JSON for GitHub Actions
$spJson = @{
    clientId = $sp.ApplicationId
    clientSecret = $spPassword.SecretText
    subscriptionId = (Get-AzContext).Subscription.Id
    tenantId = (Get-AzContext).Tenant.Id
} | ConvertTo-Json

# Save the information to a file for reference
$outputPath = "$PSScriptRoot\azure-webapp-cd-info.txt"
@"
# Azure Web App CD Information
# Generated on: $(Get-Date)

# GitHub Secrets to Add to Your Repository:
# https://github.com/kcsdevops/ari_com_interface_web/settings/secrets/actions

WEBAPP_NAME: $webAppName
RESOURCE_GROUP: $resourceGroupName
AZURE_CLIENT_ID: $($sp.ApplicationId)
AZURE_CLIENT_SECRET: $($spPassword.SecretText)
AZURE_TENANT_ID: $($(Get-AzContext).Tenant.Id)
SECRET_KEY: $secretKey

# GitHub Actions Service Principal (AZURE_CREDENTIALS secret):
$spJson

# Web App URL:
https://$webAppName.azurewebsites.net

# IMPORTANT NEXT STEPS:
1. Add the secrets above to your GitHub repository
2. Push changes to the main branch to trigger the workflow
3. Check deployment status in GitHub Actions tab
"@ | Out-File -FilePath $outputPath

Write-Host "`nSetup completed successfully!" -ForegroundColor Green
Write-Host "All necessary information has been saved to: $outputPath" -ForegroundColor Green
Write-Host "`nIMPORTANT: Add the secrets listed in the file to your GitHub repository" -ForegroundColor Yellow
Write-Host "GitHub repository: https://github.com/kcsdevops/ari_com_interface_web" -ForegroundColor Yellow
Write-Host "Secrets URL: https://github.com/kcsdevops/ari_com_interface_web/settings/secrets/actions" -ForegroundColor Yellow
