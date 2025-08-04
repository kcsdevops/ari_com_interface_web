# Script para criar recursos Azure para o webapp ARI
param(
    [string]$resourceGroupName = "ari-automation-rg",
    [string]$location = "eastus",
    [string]$acrName = "ariautomationacr",
    [string]$webAppName = "ari-automation-app",
    [string]$appServicePlanName = "ari-automation-plan",
    [string]$storageAccountName = "ariautomationstorage"
)

# Login to Azure (if not already logged in)
$context = Get-AzContext
if (-not $context.Account) {
    Connect-AzAccount
}

# Create Resource Group
Write-Host "Creating Resource Group: $resourceGroupName" -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Create Azure Container Registry
Write-Host "Creating Azure Container Registry: $acrName" -ForegroundColor Cyan
$acr = New-AzContainerRegistry -ResourceGroupName $resourceGroupName -Name $acrName -Sku Basic -EnableAdminUser

# Get ACR credentials
$acrCreds = Get-AzContainerRegistryCredential -ResourceGroupName $resourceGroupName -Name $acrName

# Create Storage Account
Write-Host "Creating Storage Account: $storageAccountName" -ForegroundColor Cyan
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -Location $location `
    -SkuName Standard_LRS `
    -Kind StorageV2

# Get Storage Account Key
$storageKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName)[0].Value
$storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$storageAccountName;AccountKey=$storageKey;EndpointSuffix=core.windows.net"

# Create App Service Plan
Write-Host "Creating App Service Plan: $appServicePlanName" -ForegroundColor Cyan
$appServicePlan = New-AzAppServicePlan -ResourceGroupName $resourceGroupName `
    -Name $appServicePlanName `
    -Location $location `
    -Tier Premium `
    -NumberofWorkers 1 `
    -Linux

# Create Web App for Containers
Write-Host "Creating Web App for Containers: $webAppName" -ForegroundColor Cyan
$webApp = New-AzWebApp -ResourceGroupName $resourceGroupName `
    -Name $webAppName `
    -Location $location `
    -AppServicePlan $appServicePlanName `
    -ContainerImageName "$($acr.LoginServer)/ari-automation:latest" `
    -ContainerRegistryUrl $acr.LoginServer `
    -ContainerRegistryUser $acrCreds.Username `
    -ContainerRegistryPassword $acrCreds.Password

# Configure Web App Settings
Write-Host "Configuring Web App Settings" -ForegroundColor Cyan
$appSettings = @{
    "WEBSITES_PORT" = "8000";
    "AZURE_STORAGE_ACCOUNT_NAME" = $storageAccountName;
    "AZURE_STORAGE_CONNECTION_STRING" = $storageConnectionString;
}

Set-AzWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -AppSettings $appSettings

# Create AAD App Registration for Web App Authentication
Write-Host "Creating AAD App Registration for Web App Authentication" -ForegroundColor Cyan
$appRegistration = New-AzADApplication -DisplayName "ARI Automation Web App" -IdentifierUris "https://$webAppName.azurewebsites.net"
$appServicePrincipal = New-AzADServicePrincipal -ApplicationId $appRegistration.ApplicationId
$appCredential = New-AzADAppCredential -ApplicationId $appRegistration.ApplicationId -EndDate (Get-Date).AddYears(1)

# Output important information
Write-Host "`nDeployment Complete!" -ForegroundColor Green
Write-Host "`nImportant Information for GitHub Secrets:" -ForegroundColor Yellow
Write-Host "ACR_URL: $($acr.LoginServer)" -ForegroundColor White
Write-Host "ACR_USERNAME: $($acrCreds.Username)" -ForegroundColor White
Write-Host "ACR_PASSWORD: $($acrCreds.Password)" -ForegroundColor White
Write-Host "WEBAPP_NAME: $webAppName" -ForegroundColor White
Write-Host "RESOURCE_GROUP: $resourceGroupName" -ForegroundColor White
Write-Host "AZURE_CLIENT_ID: $($appRegistration.ApplicationId)" -ForegroundColor White
Write-Host "AZURE_CLIENT_SECRET: $($appCredential.SecretText)" -ForegroundColor White
Write-Host "AZURE_TENANT_ID: $($(Get-AzContext).Tenant.Id)" -ForegroundColor White
Write-Host "AZURE_STORAGE_ACCOUNT_NAME: $storageAccountName" -ForegroundColor White
Write-Host "AZURE_STORAGE_CONNECTION_STRING: $storageConnectionString" -ForegroundColor White

# Generate Service Principal for GitHub Actions
Write-Host "`nCreating Service Principal for GitHub Actions" -ForegroundColor Cyan
$githubSP = New-AzADServicePrincipal -DisplayName "GitHub-ARI-Deployment"
$spPassword = New-AzADServicePrincipalCredential -ObjectId $githubSP.Id -EndDate (Get-Date).AddYears(1)

# Assign Contributor role to the service principal
New-AzRoleAssignment -ApplicationId $githubSP.ApplicationId -RoleDefinitionName Contributor -ResourceGroupName $resourceGroupName

# Output Service Principal JSON for GitHub Actions
$spJson = @{
    clientId = $githubSP.ApplicationId
    clientSecret = $spPassword.SecretText
    subscriptionId = (Get-AzContext).Subscription.Id
    tenantId = (Get-AzContext).Tenant.Id
} | ConvertTo-Json

Write-Host "`nAZURE_CREDENTIALS (for GitHub Actions):" -ForegroundColor Yellow
Write-Host $spJson -ForegroundColor White

# Save the information to a file for reference
$outputPath = "$PSScriptRoot\azure-deployment-info.txt"
@"
# Azure Deployment Information
# Generated on: $(Get-Date)

# GitHub Secrets
ACR_URL: $($acr.LoginServer)
ACR_USERNAME: $($acrCreds.Username)
ACR_PASSWORD: $($acrCreds.Password)
WEBAPP_NAME: $webAppName
RESOURCE_GROUP: $resourceGroupName
AZURE_CLIENT_ID: $($appRegistration.ApplicationId)
AZURE_CLIENT_SECRET: $($appCredential.SecretText)
AZURE_TENANT_ID: $($(Get-AzContext).Tenant.Id)
AZURE_STORAGE_ACCOUNT_NAME: $storageAccountName
AZURE_STORAGE_CONNECTION_STRING: $storageConnectionString

# GitHub Actions Service Principal
AZURE_CREDENTIALS: 
$spJson

# Web App URL
https://$webAppName.azurewebsites.net
"@ | Out-File -FilePath $outputPath

Write-Host "`nAll information saved to: $outputPath" -ForegroundColor Green
