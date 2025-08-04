# Garantindo o CD para o Azure Web App - Guia Detalhado

Este guia oferece uma abordagem passo a passo para garantir que o Continuous Deployment (CD) para o Azure Web App esteja funcionando corretamente.

## O Problema

O GitOps configurado anteriormente não está realizando o CD para o Web App. Isso pode ocorrer por diversos motivos:

1. Problemas de autenticação com o Azure
2. Configuração incorreta dos recursos no Azure
3. Problemas com a estrutura dos workflows
4. Segredos incorretos ou ausentes no GitHub

## A Solução

Implementamos uma solução simplificada e direta para garantir o CD para o Web App:

1. **Workflow Simplificado**: Criamos um workflow GitHub Actions focado apenas no essencial
2. **Script de Infraestrutura Direto**: Desenvolvemos um script PowerShell que configura apenas o necessário
3. **Autenticação Explícita**: Configuração clara dos segredos e autenticação

## Passos para Implementação

### 1. Configurar a Infraestrutura

Execute o script PowerShell para criar/atualizar a infraestrutura necessária:

```powershell
# Conecte-se ao Azure (se necessário)
Connect-AzAccount

# Execute o script
./setup-webapp-cd.ps1
```

Este script irá:
- Criar/atualizar o Resource Group
- Criar/atualizar o App Service Plan
- Criar/atualizar o Web App
- Criar um Service Principal para GitHub Actions
- Gerar todos os segredos necessários

### 2. Configurar os Segredos no GitHub

O script gerará um arquivo `azure-webapp-cd-info.txt` com todos os segredos necessários.

1. Acesse a página de segredos do seu repositório GitHub:
   https://github.com/kcsdevops/ari_com_interface_web/settings/secrets/actions

2. Adicione os seguintes segredos:
   - `WEBAPP_NAME`: Nome do Web App
   - `RESOURCE_GROUP`: Nome do Resource Group
   - `AZURE_CREDENTIALS`: JSON completo do Service Principal
   - `AZURE_CLIENT_ID`: ID do cliente do Service Principal
   - `AZURE_CLIENT_SECRET`: Segredo do Service Principal
   - `AZURE_TENANT_ID`: ID do tenant do Azure
   - `SECRET_KEY`: Chave secreta para o Flask

### 3. Garantir que o Web App está Configurado para Contêineres

Verifique no Portal do Azure:
1. Acesse o Web App
2. Em "Configurações" > "Contêiner", confirme que está configurado para usar contêineres
3. Verifique se a opção "Continuous Deployment" está habilitada

### 4. Testar o Deployment Manualmente

1. Acesse a aba "Actions" no seu repositório GitHub
2. Encontre o workflow "Azure Web App Continuous Deployment"
3. Clique em "Run workflow"
4. Selecione a branch "master" ou "main"
5. Clique em "Run workflow"

### 5. Verificar o Resultado

Após a execução do workflow:
1. Verifique se todos os passos foram executados com sucesso
2. Acesse a URL do Web App: `https://[seu-webapp-name].azurewebsites.net`
3. Verifique se a aplicação está funcionando corretamente
4. Teste o endpoint de saúde: `https://[seu-webapp-name].azurewebsites.net/health`

## Solução de Problemas

### Problemas de Autenticação

Se ocorrerem problemas de autenticação:
1. Recrie o Service Principal executando novamente o script
2. Verifique se o Service Principal tem permissões de "Contributor" no Resource Group
3. Atualize o segredo `AZURE_CREDENTIALS` no GitHub

### Falha no Build da Imagem

Se o build da imagem Docker falhar:
1. Verifique se o Dockerfile está correto
2. Teste o build localmente: `docker build -t ari-webapp:test ./webapp`
3. Verifique se todas as dependências estão listadas no `requirements.txt`

### Falha no Deployment

Se o deployment falhar:
1. Verifique os logs no Portal do Azure
2. Confirme que o Web App está configurado para usar contêineres
3. Verifique se a imagem está sendo corretamente enviada para o registro

### Aplicação não Responde

Se a aplicação for implantada mas não responder:
1. Verifique os logs do contêiner no Portal do Azure
2. Confirme que as configurações de ambiente estão corretas
3. Verifique se a porta 8000 está configurada corretamente

## Verificação Final

Para confirmar que o CD está funcionando:
1. Faça uma pequena alteração no código
2. Comite e envie para o repositório
3. Verifique se o workflow é acionado automaticamente
4. Confirme que a alteração aparece no Web App

## Próximos Passos

Uma vez que o CD básico esteja funcionando:
1. Adicione testes automatizados
2. Configure monitoramento e alertas
3. Implemente ambiente de staging
4. Configure rollback automático
