# ARI Automation com GitOps para Azure Web App

Este projeto implementa uma solução completa de GitOps para a automação do Azure Resource Inventory (ARI), permitindo a coleta e análise de dados de recursos e custos do Azure através de uma aplicação web com implantação contínua.

## 🚀 Arquitetura GitOps

A solução utiliza GitOps para gerenciar todo o ciclo de vida da aplicação:

- **Versionamento Semântico**: Versões geradas automaticamente com base em padrões de commits
- **Ambientes de Implantação**: Dev, Staging e Production, cada um com seu próprio Web App
- **Deployment Progressivo**: Pipeline de promoção automática entre ambientes
- **Rollback Automático**: Reversão automática em caso de falha na verificação de saúde
- **Slots de Implantação**: Troca de slots para implantação zero-downtime

![Arquitetura GitOps](https://raw.githubusercontent.com/kcsdevops/ari_com_interface_web/main/docs/gitops-architecture.png)

## 🏗️ Infraestrutura

A infraestrutura na Azure é composta por:

- **Resource Group**: Grupo de recursos contendo todos os componentes
- **Azure Container Registry**: Armazenamento de imagens Docker
- **Web Apps**:
  - `ari-automation-dev`: Ambiente de desenvolvimento
  - `ari-automation-staging`: Ambiente de staging
  - `ari-automation`: Ambiente de produção com slot de staging
- **Storage Account**: Armazenamento de dados e relatórios
- **Key Vault**: Armazenamento seguro de secrets
- **App Service Plan**: Plano de hospedagem para os Web Apps

## 📋 Componentes da Solução

### 1. Aplicação Web (Flask)
- Interface para execução do ARI
- Autenticação via Azure AD
- Visualização de relatórios gerados
- API para automação

### 2. Automação ARI
- Execução do módulo PowerShell do ARI
- Coleta de dados de recursos Azure
- Análise de custos
- Geração de relatórios

### 3. Pipeline de CI/CD
- Testes automatizados
- Build e publicação de imagens Docker
- Deployment progressivo entre ambientes
- Verificações de saúde e rollback automático

## 🔧 Como Configurar

### Requisitos
- Conta Azure com permissões de Owner ou Contributor
- GitHub Actions habilitado no repositório
- PowerShell 7.0+ para execução local

### Passos de Configuração

#### 1. Clone o Repositório
```bash
git clone https://github.com/kcsdevops/ari_com_interface_web.git
cd ari_com_interface_web
```

#### 2. Configure a Infraestrutura Azure
Execute o script de deployment:

```powershell
# Conecte-se ao Azure (se ainda não estiver conectado)
Connect-AzAccount

# Execute o script de deploy GitOps
./deploy-gitops.ps1 -resourceGroupName "ari-automation-rg" -location "eastus"
```

Este script criará todos os recursos necessários no Azure e gerará um arquivo com todas as informações necessárias para configurar o GitHub Actions.

#### 3. Configure os Secrets no GitHub

Adicione os secrets listados no arquivo `azure-gitops-deployment-info.txt` ao seu repositório GitHub:

1. Acesse `https://github.com/kcsdevops/ari_com_interface_web/settings/secrets/actions`
2. Adicione cada um dos secrets listados no arquivo

#### 4. Inicie o Pipeline de CI/CD

Faça um push para a branch main para iniciar o pipeline de CI/CD:

```bash
git add .
git commit -m "feat: iniciar pipeline de CI/CD"
git push origin main
```

#### 5. Monitore o Pipeline de CI/CD

Acesse `https://github.com/kcsdevops/ari_com_interface_web/actions` para monitorar o progresso do pipeline.

## 🧪 Branching e Versioning

Este projeto segue um modelo de GitFlow modificado:

- **main**: Branch principal, contém código pronto para produção
- **develop**: Branch de desenvolvimento, contém código para próxima versão
- **feature/\***: Branches para novas funcionalidades
- **release/\***: Branches para preparação de releases
- **hotfix/\***: Branches para correções urgentes

O versionamento semântico (X.Y.Z) é aplicado automaticamente:
- **X (major)**: Incrementado quando há mudanças incompatíveis ("BREAKING CHANGE" nos commits)
- **Y (minor)**: Incrementado quando há novas funcionalidades (commits com "feat:")
- **Z (patch)**: Incrementado quando há correções de bugs (commits com "fix:")

## 📚 Guia de Uso

### Executar o ARI Localmente

```powershell
# Execute o script ARI com PowerShell 7
pwsh -File ./run_ari.ps1 -TenantID "<seu-tenant-id>" -IncludeCosts -IncludeTags
```

### Acessar a Aplicação Web

Após a implantação, acesse a aplicação nos seguintes URLs:

- **Dev**: https://ari-automation-dev.azurewebsites.net
- **Staging**: https://ari-automation-staging.azurewebsites.net
- **Produção**: https://ari-automation.azurewebsites.net

## 🔄 Fluxo de CI/CD

1. **Commit/Push**: Alterações enviadas ao repositório
2. **Build & Test**: Código é testado e a imagem Docker é construída
3. **Deploy to Dev**: Implantação automática no ambiente de desenvolvimento
4. **Health Check**: Verificação de saúde da aplicação
5. **Deploy to Staging**: Promoção automática para ambiente de staging
6. **Health Check**: Verificação de saúde da aplicação
7. **Deploy to Production**: Promoção para o slot de staging da produção
8. **Health Check**: Verificação de saúde da aplicação
9. **Slot Swap**: Troca dos slots de staging e produção
10. **Final Health Check**: Verificação final de saúde
11. **Auto Rollback**: Rollback automático em caso de falha

## 🔒 Segurança

- Autenticação via Azure AD
- Secrets armazenados no Key Vault
- HTTPS obrigatório
- Conexões seguras com APIs do Azure
- Permissões de menor privilégio para Service Principals

## 📊 Monitoramento

- Health checks automatizados
- Logs centralizados
- Métricas de aplicação
- Alertas configuráveis

## 📝 Licença

Este projeto é licenciado sob a [Licença MIT](LICENSE).

## 📬 Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Fork o repositório
2. Crie uma branch feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas alterações (`git commit -m 'feat: adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request
