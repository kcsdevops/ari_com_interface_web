# ARI Automation Web Interface

Este projeto implementa uma interface web para automação do Azure Resource Inventory (ARI), permitindo a coleta e análise de dados de recursos e custos do Azure através de uma aplicação web.

## Características

- Interface web para execução do ARI
- Autenticação via Azure AD
- Execução assíncrona do ARI
- Visualização de relatórios
- Integração com Power BI para análise de custos
- Containerização com Docker

## Estrutura do Projeto

`
├── ARI/                   # Azure Resource Inventory (módulo PowerShell)
├── config/                # Configurações da aplicação
├── data/                  # Diretório para dados gerados pelo ARI
│   ├── ari_output/        # Saída do ARI
│   └── processed/         # Dados processados
├── logs/                  # Logs da aplicação
├── reports/               # Relatórios gerados
├── src/                   # Código-fonte da automação
│   ├── automation/        # Scripts de automação do ARI
│   ├── azure/             # Integração com Azure APIs
│   ├── cost_analysis/     # Análise de custos
│   ├── data_processing/   # Processamento de dados
│   ├── powerbi/           # Integração com Power BI
│   └── utils/             # Utilitários
├── terraform/             # Infraestrutura como código
├── webapp/                # Aplicação web Flask
│   ├── templates/         # Templates HTML
│   ├── app.py             # Aplicação principal
│   └── Dockerfile         # Definição do contêiner Docker
├── run_ari.ps1            # Script PowerShell para execução do ARI
├── deploy-webapp.ps1      # Script para deploy no Azure
└── README.md              # Este arquivo
`

## Requisitos

- Python 3.9+
- PowerShell 7.0+
- Módulos Azure PowerShell
- Docker (para desenvolvimento local)
- Conta Azure com permissões apropriadas

## Configuração e Instalação

### 1. Clone o repositório

`ash
git clone https://github.com/kcsdevops/ari_com_interface_web.git
cd ari_com_interface_web
`

### 2. Configuração do Ambiente

`ash
# Criar ambiente virtual Python
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
.\.venv\Scripts\Activate.ps1  # Windows PowerShell

# Instalar dependências
pip install -r requirements.txt
`

### 3. Configurar Variáveis de Ambiente

Crie um arquivo .env na pasta raiz com as seguintes variáveis:

`
AZURE_CLIENT_ID=seu_client_id
AZURE_CLIENT_SECRET=seu_client_secret
AZURE_TENANT_ID=seu_tenant_id
AZURE_STORAGE_ACCOUNT_NAME=seu_storage_account
AZURE_STORAGE_CONNECTION_STRING=sua_connection_string
SECRET_KEY=chave_secreta_para_flask
`

### 4. Executar Localmente

`ash
# Iniciar a aplicação web
cd webapp
python app.py
`

## Deploy no Azure

### Usando o Script de Deploy

`powershell
# Execute o script de deploy para criar os recursos necessários no Azure
pwsh -File .\deploy-webapp.ps1
`

### Usando GitHub Actions

O projeto inclui workflows do GitHub Actions para CI/CD automatizado. Para usá-los:

1. Configure os secrets necessários no repositório GitHub:
   - AZURE_CREDENTIALS: Credenciais do Service Principal
   - AZURE_WEBAPP_NAME: Nome do Web App
   - AZURE_RESOURCE_GROUP: Grupo de recursos
   - AZURE_CONTAINERAPP_NAME: (opcional) Nome do Container App

2. Faça push para a branch main para iniciar o deployment

## Executando o ARI

### Via Interface Web

1. Acesse a aplicação web
2. Faça login com credenciais Azure AD
3. Vá para a página "Run ARI"
4. Configure os parâmetros e execute

### Via Script PowerShell

`powershell
# Executar diretamente via PowerShell
pwsh -File .\run_ari.ps1 -TenantID "seu-tenant-id" -IncludeCosts -IncludeTags
`

## Contribuição

Contribuições são bem-vindas! Por favor, siga estas etapas:

1. Fork o repositório
2. Crie uma branch para sua feature (git checkout -b feature/nova-feature)
3. Commit suas mudanças (git commit -am 'Adiciona nova feature')
4. Push para a branch (git push origin feature/nova-feature)
5. Crie um Pull Request

## Licença

Este projeto é licenciado sob a licença MIT - veja o arquivo LICENSE para detalhes.
