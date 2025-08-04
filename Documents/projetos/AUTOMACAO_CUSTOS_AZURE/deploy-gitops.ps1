# Script para criar infraestrutura GitOps no Azure Web App com múltiplos ambientes

param(
    [string]$resourceGroupName = "ari-automation-rg",
    [string]$location = "eastus",
    [string]$acrName = "ariautomationacr",
    [string]$webAppBaseName = "ari-automation",
    [string]$appServicePlanName = "ari-automation-plan",
    [string]$storageAccountName = "ariautomationstorage",
    [ValidateSet("Basic", "Standard", "Premium", "PremiumV2")]
    [string]$appServicePlanSku = "PremiumV2",
    [ValidateSet("Small", "Medium", "Large")]
    [string]$appServicePlanSize = "Small"
)

# Login to Azure (if not already logged in)
$context = Get-AzContext
if (-not $context.Account) {
    Connect-AzAccount
}

# Output header
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "             AZURE WEB APP GITOPS INFRASTRUCTURE DEPLOYMENT              " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "This script will create the following resources:"
Write-Host "- Resource Group: $resourceGroupName"
Write-Host "- Container Registry: $acrName"
Write-Host "- Storage Account: $storageAccountName"
Write-Host "- App Service Plan: $appServicePlanName ($appServicePlanSku-$appServicePlanSize)"
Write-Host "- Web Apps:"
Write-Host "  - DEV: $webAppBaseName-dev"
Write-Host "  - STAGING: $webAppBaseName-staging"
Write-Host "  - PRODUCTION: $webAppBaseName (with staging slot)"
Write-Host "- Service Principals for GitHub Actions"
Write-Host "- Key Vault for secrets management"
Write-Host "=========================================================================" -ForegroundColor Cyan

Write-Host "`nCreating Resource Group: $resourceGroupName" -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force | Out-Null

# Create Azure Container Registry
Write-Host "`nCreating Azure Container Registry: $acrName" -ForegroundColor Cyan
$acr = New-AzContainerRegistry -ResourceGroupName $resourceGroupName -Name $acrName -Sku Basic -EnableAdminUser -ErrorAction SilentlyContinue
if (-not $acr) {
    $acr = Get-AzContainerRegistry -ResourceGroupName $resourceGroupName -Name $acrName
    Write-Host "Using existing ACR: $acrName" -ForegroundColor Yellow
} else {
    Write-Host "ACR created successfully" -ForegroundColor Green
}

# Get ACR credentials
$acrCreds = Get-AzContainerRegistryCredential -ResourceGroupName $resourceGroupName -Name $acrName

# Create Storage Account
Write-Host "`nCreating Storage Account: $storageAccountName" -ForegroundColor Cyan
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName Standard_LRS -Kind StorageV2 -ErrorAction SilentlyContinue
if (-not $storageAccount) {
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    Write-Host "Using existing Storage Account: $storageAccountName" -ForegroundColor Yellow
} else {
    Write-Host "Storage Account created successfully" -ForegroundColor Green
}

# Get Storage Account Key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageKey;EndpointSuffix=core.windows.net"

# Create containers in the storage account
$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey
New-AzStorageContainer -Name "ari-reports" -Context $context -Permission Off -ErrorAction SilentlyContinue
New-AzStorageContainer -Name "ari-data" -Context $context -Permission Off -ErrorAction SilentlyContinue
New-AzStorageContainer -Name "ari-powerbi" -Context $context -Permission Off -ErrorAction SilentlyContinue

# Create Key Vault
$keyVaultName = "$webAppBaseName-kv"
Write-Host "`nCreating Key Vault: $keyVaultName" -ForegroundColor Cyan
$keyVault = New-AzKeyVault -Name $keyVaultName -ResourceGroupName $resourceGroupName -Location $location -ErrorAction SilentlyContinue
if (-not $keyVault) {
    $keyVault = Get-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName
    Write-Host "Using existing Key Vault: $keyVaultName" -ForegroundColor Yellow
} else {
    Write-Host "Key Vault created successfully" -ForegroundColor Green
}

# Create App Service Plan
Write-Host "`nCreating App Service Plan: $appServicePlanName" -ForegroundColor Cyan
$appServicePlan = New-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName -Location $location -Tier $appServicePlanSku -WorkerSize $appServicePlanSize -Linux -ErrorAction SilentlyContinue
if (-not $appServicePlan) {
    $appServicePlan = Get-AzAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlanName
    Write-Host "Using existing App Service Plan: $appServicePlanName" -ForegroundColor Yellow
} else {
    Write-Host "App Service Plan created successfully" -ForegroundColor Green
}

# Create Web Apps for each environment
# DEV Environment
$devWebAppName = "$webAppBaseName-dev"
Write-Host "`nCreating Dev Web App: $devWebAppName" -ForegroundColor Cyan
$devWebApp = New-AzWebApp -ResourceGroupName $resourceGroupName -Name $devWebAppName -Location $location -AppServicePlan $appServicePlanName -ContainerImageName "$($acr.LoginServer)/ari-automation:latest" -ContainerRegistryUrl $acr.LoginServer -ContainerRegistryUser $acrCreds.Username -ContainerRegistryPassword $acrCreds.Password -ErrorAction SilentlyContinue
if (-not $devWebApp) {
    $devWebApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $devWebAppName
    Write-Host "Using existing Dev Web App: $devWebAppName" -ForegroundColor Yellow
} else {
    Write-Host "Dev Web App created successfully" -ForegroundColor Green
}

# STAGING Environment
$stagingWebAppName = "$webAppBaseName-staging"
Write-Host "`nCreating Staging Web App: $stagingWebAppName" -ForegroundColor Cyan
$stagingWebApp = New-AzWebApp -ResourceGroupName $resourceGroupName -Name $stagingWebAppName -Location $location -AppServicePlan $appServicePlanName -ContainerImageName "$($acr.LoginServer)/ari-automation:latest" -ContainerRegistryUrl $acr.LoginServer -ContainerRegistryUser $acrCreds.Username -ContainerRegistryPassword $acrCreds.Password -ErrorAction SilentlyContinue
if (-not $stagingWebApp) {
    $stagingWebApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $stagingWebAppName
    Write-Host "Using existing Staging Web App: $stagingWebAppName" -ForegroundColor Yellow
} else {
    Write-Host "Staging Web App created successfully" -ForegroundColor Green
}

# PRODUCTION Environment
$prodWebAppName = $webAppBaseName
Write-Host "`nCreating Production Web App: $prodWebAppName" -ForegroundColor Cyan
$prodWebApp = New-AzWebApp -ResourceGroupName $resourceGroupName -Name $prodWebAppName -Location $location -AppServicePlan $appServicePlanName -ContainerImageName "$($acr.LoginServer)/ari-automation:latest" -ContainerRegistryUrl $acr.LoginServer -ContainerRegistryUser $acrCreds.Username -ContainerRegistryPassword $acrCreds.Password -ErrorAction SilentlyContinue
if (-not $prodWebApp) {
    $prodWebApp = Get-AzWebApp -ResourceGroupName $resourceGroupName -Name $prodWebAppName
    Write-Host "Using existing Production Web App: $prodWebAppName" -ForegroundColor Yellow
} else {
    Write-Host "Production Web App created successfully" -ForegroundColor Green
}

# Create staging slot for production
Write-Host "`nCreating Staging Slot for Production Web App" -ForegroundColor Cyan
$stagingSlot = New-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $prodWebAppName -Slot "staging" -ContainerImageName "$($acr.LoginServer)/ari-automation:latest" -ContainerRegistryUrl $acr.LoginServer -ContainerRegistryUser $acrCreds.Username -ContainerRegistryPassword $acrCreds.Password -ErrorAction SilentlyContinue
if (-not $stagingSlot) {
    $stagingSlot = Get-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $prodWebAppName -Slot "staging"
    Write-Host "Using existing Staging Slot" -ForegroundColor Yellow
} else {
    Write-Host "Staging Slot created successfully" -ForegroundColor Green
}

# Configure common settings for all web apps
$commonSettings = @{
    "WEBSITES_PORT" = "8000";
    "WEBSITES_CONTAINER_START_TIME_LIMIT" = "600";
    "AZURE_STORAGE_ACCOUNT_NAME" = $storageAccountName;
    "AZURE_STORAGE_CONNECTION_STRING" = $storageConnectionString;
    "DOCKER_REGISTRY_SERVER_URL" = "https://$($acr.LoginServer)";
    "DOCKER_REGISTRY_SERVER_USERNAME" = $acrCreds.Username;
    "DOCKER_REGISTRY_SERVER_PASSWORD" = $acrCreds.Password;
    "DOCKER_ENABLE_CI" = "true";
}

# Apply settings to all web apps
Write-Host "`nConfiguring Web App Settings" -ForegroundColor Cyan
Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $devWebAppName -AppSettings ($commonSettings + @{"ENVIRONMENT" = "development"}) | Out-Null
Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $stagingWebAppName -AppSettings ($commonSettings + @{"ENVIRONMENT" = "staging"}) | Out-Null
Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $prodWebAppName -AppSettings ($commonSettings + @{"ENVIRONMENT" = "production"}) | Out-Null
Set-AzWebAppSlot -ResourceGroupName $resourceGroupName -Name $prodWebAppName -Slot "staging" -AppSettings ($commonSettings + @{"ENVIRONMENT" = "production-staging"}) | Out-Null

Write-Host "Web App Settings configured successfully" -ForegroundColor Green

# Create AAD App Registration for Web App Authentication
Write-Host "`nCreating AAD App Registration for Web App Authentication" -ForegroundColor Cyan
$appRegistration = New-AzADApplication -DisplayName "ARI Automation Web App" -IdentifierUris "https://$prodWebAppName.azurewebsites.net" -ErrorAction SilentlyContinue
if (-not $appRegistration) {
    $appRegistration = Get-AzADApplication -DisplayName "ARI Automation Web App" | Where-Object { $_.IdentifierUris -contains "https://$prodWebAppName.azurewebsites.net" }
    Write-Host "Using existing App Registration" -ForegroundColor Yellow
} else {
    Write-Host "App Registration created successfully" -ForegroundColor Green
}

$appServicePrincipal = New-AzADServicePrincipal -ApplicationId $appRegistration.ApplicationId -ErrorAction SilentlyContinue
if (-not $appServicePrincipal) {
    $appServicePrincipal = Get-AzADServicePrincipal -ApplicationId $appRegistration.ApplicationId
    Write-Host "Using existing Service Principal" -ForegroundColor Yellow
} else {
    Write-Host "Service Principal created successfully" -ForegroundColor Green
}

$appCredential = New-AzADAppCredential -ApplicationId $appRegistration.ApplicationId -EndDate (Get-Date).AddYears(1) -ErrorAction SilentlyContinue
Write-Host "App Credential created successfully" -ForegroundColor Green

# Add secrets to Key Vault
Write-Host "`nAdding secrets to Key Vault" -ForegroundColor Cyan
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AzureClientId" -SecretValue (ConvertTo-SecureString -String $appRegistration.ApplicationId -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AzureClientSecret" -SecretValue (ConvertTo-SecureString -String $appCredential.SecretText -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AzureTenantId" -SecretValue (ConvertTo-SecureString -String $(Get-AzContext).Tenant.Id -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AzureStorageAccountName" -SecretValue (ConvertTo-SecureString -String $storageAccountName -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AzureStorageConnectionString" -SecretValue (ConvertTo-SecureString -String $storageConnectionString -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AcrUsername" -SecretValue (ConvertTo-SecureString -String $acrCreds.Username -AsPlainText -Force) | Out-Null
Set-AzKeyVaultSecret -VaultName $keyVaultName -Name "AcrPassword" -SecretValue (ConvertTo-SecureString -String $acrCreds.Password -AsPlainText -Force) | Out-Null

Write-Host "Key Vault secrets added successfully" -ForegroundColor Green

# Generate Service Principal for GitHub Actions
Write-Host "`nCreating Service Principal for GitHub Actions" -ForegroundColor Cyan
$githubSP = New-AzADServicePrincipal -DisplayName "GitHub-ARI-GitOps-Deployment" -ErrorAction SilentlyContinue
if (-not $githubSP) {
    $githubSP = Get-AzADServicePrincipal -DisplayName "GitHub-ARI-GitOps-Deployment"
    Write-Host "Using existing GitHub Service Principal" -ForegroundColor Yellow
} else {
    Write-Host "GitHub Service Principal created successfully" -ForegroundColor Green
}

$spPassword = New-AzADServicePrincipalCredential -ObjectId $githubSP.Id -EndDate (Get-Date).AddYears(1) -ErrorAction SilentlyContinue

# Assign Contributor role to the service principal
New-AzRoleAssignment -ApplicationId $githubSP.ApplicationId -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue | Out-Null

# Output Service Principal JSON for GitHub Actions
$spJson = @{
    clientId = $githubSP.ApplicationId
    clientSecret = $spPassword.SecretText
    subscriptionId = (Get-AzContext).Subscription.Id
    tenantId = (Get-AzContext).Tenant.Id
} | ConvertTo-Json

# Generate random Secret Key for Flask
$secretKey = [System.Convert]::ToBase64String((New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes(32))

# Save the information to a file for reference
$outputPath = "$PSScriptRoot\azure-gitops-deployment-info.txt"
@"
# Azure GitOps Deployment Information
# Generated on: $(Get-Date)

# GitHub Secrets
ACR_URL: $($acr.LoginServer)
ACR_USERNAME: $($acrCreds.Username)
ACR_PASSWORD: $($acrCreds.Password)
WEBAPP_NAME: $prodWebAppName
RESOURCE_GROUP: $resourceGroupName
AZURE_CLIENT_ID: $($appRegistration.ApplicationId)
AZURE_CLIENT_SECRET: $($appCredential.SecretText)
AZURE_TENANT_ID: $($(Get-AzContext).Tenant.Id)
AZURE_STORAGE_ACCOUNT_NAME: $storageAccountName
AZURE_STORAGE_CONNECTION_STRING: $storageConnectionString
SECRET_KEY: $secretKey

# GitHub Actions Service Principal
AZURE_CREDENTIALS: 
$spJson

# Web App URLs
DEV: https://$devWebAppName.azurewebsites.net
STAGING: https://$stagingWebAppName.azurewebsites.net
PRODUCTION: https://$prodWebAppName.azurewebsites.net
PRODUCTION STAGING SLOT: https://$prodWebAppName-staging.azurewebsites.net

# Key Vault
KEY_VAULT_NAME: $keyVaultName
"@ | Out-File -FilePath $outputPath

Write-Host "`nAll information saved to: $outputPath" -ForegroundColor Green

Write-Host "`n=========================================================================" -ForegroundColor Cyan
Write-Host "             GITOPS INFRASTRUCTURE DEPLOYMENT COMPLETE                   " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "Follow these steps to complete the setup:"
Write-Host "1. Add the GitHub Secrets to your repository at:"
Write-Host "   https://github.com/kcsdevops/ari_com_interface_web/settings/secrets/actions"
Write-Host "2. Push a commit to the main branch to trigger the CI/CD pipeline"
Write-Host "3. Monitor the deployment at:"
Write-Host "   https://github.com/kcsdevops/ari_com_interface_web/actions"
Write-Host "4. Access your web apps at:"
Write-Host "   DEV: https://$devWebAppName.azurewebsites.net"
Write-Host "   STAGING: https://$stagingWebAppName.azurewebsites.net"
Write-Host "   PRODUCTION: https://$prodWebAppName.azurewebsites.net"
Write-Host "=========================================================================" -ForegroundColor Cyan
