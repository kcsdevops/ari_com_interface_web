# Automação ARI - Instruções de Deploy

Este documento contém as instruções para configurar o deploy automatizado da aplicação ARI Web Interface para o Azure Web App usando GitHub Actions.

## Pré-requisitos

1. Uma conta do Azure
2. Permissões para criar recursos no Azure (Contributor ou Owner)
3. Um repositório GitHub (https://github.com/kcsdevops/ari_com_interface_web.git)

## Passos para Configuração do GitOps

### 1. Criar os Recursos no Azure

Execute o script `deploy-webapp.ps1` para criar os recursos necessários no Azure:

```powershell
./deploy-webapp.ps1 -resourceGroupName "ari-automation-rg" -location "eastus" -webAppName "ari-automation-app"
```

Este script irá:
- Criar um Resource Group
- Criar um Azure Container Registry (ACR)
- Criar uma Storage Account
- Criar um App Service Plan
- Criar um Web App for Containers
- Configurar AAD App Registration para autenticação
- Criar um Service Principal para GitHub Actions

### 2. Configurar Secrets no GitHub

Adicione os seguintes secrets no seu repositório GitHub:

- `ACR_URL`: URL do Azure Container Registry
- `ACR_USERNAME`: Nome de usuário do ACR
- `ACR_PASSWORD`: Senha do ACR
- `WEBAPP_NAME`: Nome do Web App
- `RESOURCE_GROUP`: Nome do Resource Group
- `AZURE_CLIENT_ID`: Client ID do app registration
- `AZURE_CLIENT_SECRET`: Client Secret do app registration
- `AZURE_TENANT_ID`: Tenant ID do Azure AD
- `AZURE_STORAGE_ACCOUNT_NAME`: Nome da Storage Account
- `AZURE_STORAGE_CONNECTION_STRING`: Connection string da Storage Account
- `AZURE_CREDENTIALS`: JSON com credenciais do Service Principal (gerado pelo script deploy-webapp.ps1)

### 3. Workflow de CI/CD

O workflow do GitHub Actions (`.github/workflows/deploy-webapp.yml`) está configurado para:

1. Ser acionado em pushes para a branch `main` ou manualmente
2. Construir a imagem Docker da aplicação
3. Enviar a imagem para o Azure Container Registry
4. Implantar a imagem no Azure Web App
5. Configurar as variáveis de ambiente necessárias

### 4. Monitoramento do Deploy

Você pode monitorar o progresso do deploy:

1. Na aba "Actions" do repositório GitHub
2. No portal do Azure, na seção "Deployments" do Web App

## Verificação do Deploy

Após o deploy, acesse a aplicação em:
`https://[seu-webapp-name].azurewebsites.net`

## Solução de Problemas

### Falha no Build da Imagem Docker
- Verifique se o Dockerfile está corretamente configurado
- Verifique se as credenciais do ACR estão corretas

### Falha no Deploy para o Web App
- Verifique se o Service Principal tem permissões suficientes
- Verifique os logs do Web App no portal do Azure

### Problemas de Autenticação
- Verifique se as configurações do App Registration estão corretas
- Verifique se as URLs de redirecionamento estão configuradas corretamente

## Próximos Passos

1. Configurar monitoramento com Azure Application Insights
2. Implementar testes automatizados
3. Configurar alertas para falhas de execução do ARI

---

Para mais informações, consulte a documentação do [Azure Web App](https://docs.microsoft.com/azure/app-service/) e [GitHub Actions](https://docs.github.com/actions).
