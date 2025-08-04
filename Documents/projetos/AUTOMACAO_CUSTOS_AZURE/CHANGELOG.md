# Changelog

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Pipeline de CI/CD GitOps completo
- Versionamento semântico automático
- Ambientes de desenvolvimento, staging e produção
- Rollback automático em caso de falha
- Deployment zero-downtime com slots
- Instruções detalhadas para GitOps

## [1.0.0] - 2025-08-04

### Adicionado
- Interface web para execução do ARI
- Autenticação via Azure AD
- Execução assíncrona do ARI
- Visualização de relatórios
- Containerização com Docker
- Script PowerShell robusto para ARI

### Alterado
- Migração da interface de linha de comando para web
- Reestruturação do código em módulos Python

### Corrigido
- Problemas de timeout na execução do ARI
- Erros de caracteres em relatórios
- Problemas de linha de comando em diferentes sistemas

## [0.2.0] - 2025-07-15

### Adicionado
- Integração com Azure Cost Management
- Análise de custos nos relatórios
- Exportação para Power BI
- Logging melhorado

### Alterado
- Refatoração da lógica de processamento de dados
- Otimização de consultas Azure

## [0.1.0] - 2025-06-01

### Adicionado
- Versão inicial do ARI Automation
- Script PowerShell para execução do ARI
- Coleta básica de recursos Azure
- Geração de relatórios Excel
