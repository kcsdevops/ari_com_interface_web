# Guia de Versionamento e GitOps

Este documento descreve as práticas de versionamento e o fluxo de GitOps para o projeto ARI Automation.

## Estratégia de Versionamento

O projeto utiliza versionamento semântico (SemVer) no formato `MAJOR.MINOR.PATCH` (X.Y.Z):

- **MAJOR (X)**: Alterações incompatíveis com versões anteriores
- **MINOR (Y)**: Adição de funcionalidades de forma compatível
- **PATCH (Z)**: Correções de bugs compatíveis com versões anteriores

### Prefixos de Commit

Para permitir o versionamento automático, os commits devem seguir o padrão:

- `feat:` - Nova funcionalidade (incrementa MINOR)
- `fix:` - Correção de bug (incrementa PATCH)
- `docs:` - Apenas documentação (não incrementa versão)
- `style:` - Formatação, ponto-e-vírgula, etc. (não incrementa versão)
- `refactor:` - Refatoração de código (não incrementa versão)
- `test:` - Adição ou correção de testes (não incrementa versão)
- `chore:` - Tarefas de build, dependências, etc. (não incrementa versão)

Para indicar uma mudança incompatível (incrementa MAJOR), inclua `BREAKING CHANGE:` no corpo do commit.

### Exemplos:

```
feat: adiciona recurso de exportação para CSV
```

```
fix: corrige problema de autenticação no Azure AD
```

```
feat: migra para novo modelo de dados

BREAKING CHANGE: A estrutura de dados não é mais compatível com versões anteriores
```

## Fluxo de Trabalho GitOps

### Branches

- `main`: Código de produção
- `develop`: Desenvolvimento contínuo
- `feature/*`: Novas funcionalidades
- `release/*`: Preparação para release
- `hotfix/*`: Correções urgentes para produção

### Fluxo de Desenvolvimento

1. **Iniciar Nova Funcionalidade**:
   ```bash
   git checkout develop
   git pull
   git checkout -b feature/nova-funcionalidade
   # Desenvolva a funcionalidade
   git commit -m "feat: adiciona nova funcionalidade"
   git push origin feature/nova-funcionalidade
   ```

2. **Criar Pull Request**:
   - Crie um PR da branch `feature/nova-funcionalidade` para `develop`
   - Aguarde revisão e testes automatizados
   - Após aprovação, faça o merge

3. **Preparar Release**:
   ```bash
   git checkout develop
   git pull
   git checkout -b release/v1.2.0
   # Faça ajustes finais, atualize CHANGELOG, etc.
   git commit -m "chore: prepara release v1.2.0"
   git push origin release/v1.2.0
   ```

4. **Finalizar Release**:
   - Crie um PR da branch `release/v1.2.0` para `main`
   - Após aprovação e merge, crie uma tag:
   ```bash
   git checkout main
   git pull
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```

5. **Hotfix para Produção**:
   ```bash
   git checkout main
   git pull
   git checkout -b hotfix/correcao-urgente
   # Faça a correção
   git commit -m "fix: corrige problema crítico"
   git push origin hotfix/correcao-urgente
   ```
   - Crie PRs para `main` e `develop`

## Pipeline de CI/CD

A pipeline de CI/CD é acionada automaticamente e segue o fluxo:

1. **Verificação**: Código é verificado e testado
2. **Versionamento**: Versão é gerada automaticamente
3. **Build**: Imagem Docker é construída e publicada
4. **Deploy DEV**: Implantação no ambiente de desenvolvimento
5. **Testes de Integração**: Testes automatizados no ambiente DEV
6. **Deploy STAGING**: Promoção para ambiente de staging
7. **Aprovação**: Aprovação manual (opcional, apenas para PROD)
8. **Deploy PROD**: Implantação no ambiente de produção
9. **Verificações Pós-Deploy**: Testes de saúde e integração

## Monitoramento do Deployment

Você pode monitorar o status dos deployments:

1. **GitHub Actions**: https://github.com/kcsdevops/ari_com_interface_web/actions
2. **Azure Portal**: https://portal.azure.com (Web Apps > Deployments)
3. **URLs da Aplicação**:
   - DEV: https://ari-automation-dev.azurewebsites.net
   - STAGING: https://ari-automation-staging.azurewebsites.net
   - PROD: https://ari-automation.azurewebsites.net

## Rollback

### Rollback Automático

O pipeline inclui verificações de saúde e rollback automático:

1. Após deployment, o sistema faz verificações de saúde
2. Se falhar, reverte automaticamente para a versão anterior
3. Notificações são enviadas para equipe

### Rollback Manual

Para rollback manual:

1. **Via Azure Portal**:
   - Acesse o Web App no portal Azure
   - Vá para Deployment Center > Logs
   - Selecione uma implantação anterior e clique em "Redeploy"

2. **Via GitHub Actions**:
   - Acesse GitHub Actions no repositório
   - Execute o workflow "ARI GitOps CI/CD Pipeline" manualmente
   - Selecione a tag/versão anterior para reimplantar

## Boas Práticas

1. **Commits Atômicos**: Faça commits pequenos e focados
2. **Mensagens Claras**: Use os prefixos corretos nas mensagens
3. **Testes**: Adicione testes para novas funcionalidades
4. **Pull Requests**: Descreva claramente as alterações nos PRs
5. **Documentação**: Atualize a documentação conforme necessário
6. **CHANGELOG**: Mantenha o CHANGELOG.md atualizado
7. **Code Review**: Faça revisões de código minuciosas
