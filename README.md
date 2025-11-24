# Docling Ingest Boilerplate for Azure Functions

A production-ready Azure Functions application for automated PDF document processing and ingestion. This project converts the Docling ingestion Jupyter notebook into an edge-function executable Python script that processes PDFs from SharePoint folders, extracts text and figures, generates embeddings using VoyageAI, and stores structured chunks in MongoDB Atlas.

## Purpose

This repository provides a reusable, serverless solution for document processing and ingestion workflows using Azure Functions. It's designed to:

- **Automate PDF ingestion** from SharePoint document libraries
- **Extract and process content** using Docling's advanced document understanding
- **Generate semantic embeddings** with VoyageAI's contextualized embedding models
- **Store structured data** in MongoDB Atlas with vector search capabilities
- **Deploy as Azure Functions** for scalable, event-driven processing

## Features

✅ **SharePoint Integration** - Iterate over PDF files in SharePoint folders with Microsoft Graph API  
✅ **Azure Functions Ready** - HTTP-triggered functions for serverless execution  
✅ **Secure Configuration** - Environment-based secrets management (no hardcoded credentials)  
✅ **GitHub Actions Support** - CI/CD pipeline with GitHub Secrets integration  
✅ **Comprehensive Logging** - Detailed logging for debugging and monitoring  
✅ **Flexible Source Support** - SharePoint folders or Azure Blob Storage  
✅ **Vector Search Ready** - MongoDB Atlas vector index support for semantic search

## Architecture

```
SharePoint Folder → Azure Function → Docling Processing → VoyageAI Embeddings → MongoDB Atlas
```

The function app includes:
- `ingest_sharepoint_folder` - Process all PDFs in a SharePoint folder
- `ingest_single_pdf` - Process a single PDF from SharePoint or Blob Storage
- `health` - Health check endpoint

## Prerequisites

Before setting up this project, ensure you have:

- **Python 3.9+** installed
- **Azure Account** with an active subscription
- **Azure Functions Core Tools** (for local development)
- **Azure CLI** (for deployment)
- **SharePoint Site** with document library access
- **Azure AD App Registration** (for SharePoint authentication)
- **MongoDB Atlas Account** (free tier works fine)
- **VoyageAI API Key** (sign up at https://voyage.ai)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/le-dawg/docling-ingest-boilerplate.git
cd docling-ingest-boilerplate
```

### 2. Install Dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install requirements
pip install -r requirements.txt

# Install Azure Functions Core Tools
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

### 3. Configure Environment Variables

Copy the example environment file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env` with your actual values (see Configuration section below).

### 4. Run Locally

```bash
# Start the Azure Functions runtime
func start
```

The function app will be available at `http://localhost:7071`.

### 5. Test the Function

**Process SharePoint folder:**
```bash
curl -X POST http://localhost:7071/api/ingest_sharepoint_folder \
  -H "Content-Type: application/json" \
  -d '{
    "folder_path": "Shared Documents/PDFs",
    "max_files": 5
  }'
```

**Process single PDF:**
```bash
curl -X POST http://localhost:7071/api/ingest_single_pdf \
  -H "Content-Type: application/json" \
  -d '{
    "source_type": "sharepoint",
    "file_name": "document.pdf",
    "folder_path": "Shared Documents/PDFs"
  }'
```

## Configuration

### SharePoint App Registration

To access SharePoint, you need to create an Azure AD App Registration:

1. **Navigate to Azure Portal** → Azure Active Directory → App registrations
2. **Click "New registration"**
   - Name: `Docling Ingest Function`
   - Supported account types: Accounts in this organizational directory only
   - Redirect URI: (leave blank)
3. **Note the Application (client) ID and Directory (tenant) ID**
4. **Create a client secret:**
   - Go to Certificates & secrets → New client secret
   - Description: `Function App Secret`
   - Expires: Choose appropriate duration
   - **Copy the secret value immediately** (you won't see it again)
5. **Add API permissions:**
   - Click "API permissions" → Add a permission
   - Microsoft Graph → Application permissions
   - Add: `Sites.Read.All`, `Files.Read.All`
   - Click "Grant admin consent"

### Environment Variables

Edit your `.env` file with the following configuration:

```bash
# SharePoint Configuration
SHAREPOINT_TENANT_ID=your-tenant-id-from-step-3
SHAREPOINT_CLIENT_ID=your-client-id-from-step-3
SHAREPOINT_CLIENT_SECRET=your-client-secret-from-step-4
SHAREPOINT_SITE_URL=https://yourtenant.sharepoint.com/sites/yoursite
SHAREPOINT_FOLDER_PATH=Shared Documents/PDFs

# VoyageAI Configuration
VOYAGE_API_KEY=your-voyage-api-key

# MongoDB Configuration
MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/?retryWrites=true&w=majority
MONGODB_DB=docling_ingestion
MONGODB_COLLECTION=pdf_chunks
VECTOR_INDEX=embedding_vector_index

# Optional: Azure Storage (alternative source)
AZURE_STORAGE_CONNECTION_STRING=DefaultEndpointsProtocol=https;AccountName=...

# Processing Configuration (optional)
CHUNK_MAX_TOKENS=768
VOYAGE_OUTPUT_DIM=1024
```

### MongoDB Atlas Setup

1. **Create a free cluster** at https://www.mongodb.com/cloud/atlas
2. **Create a database user** with read/write permissions
3. **Whitelist your IP** or use 0.0.0.0/0 for Azure Functions
4. **Copy connection string** and update `MONGODB_URI` in `.env`
5. **Create vector search index** (after first ingestion):
   ```javascript
   {
     "fields": [
       {
         "type": "vector",
         "path": "embedding",
         "numDimensions": 1024,
         "similarity": "cosine"
       }
     ]
   }
   ```

## Deployment to Azure

### Option 1: Using Azure CLI

```bash
# Login to Azure
az login

# Create resource group
az group create --name docling-ingest-rg --location eastus

# Create storage account (required for Azure Functions)
az storage account create \
  --name doclingingeststorage \
  --resource-group docling-ingest-rg \
  --location eastus \
  --sku Standard_LRS

# Create Function App (Linux, Python 3.9)
az functionapp create \
  --resource-group docling-ingest-rg \
  --consumption-plan-location eastus \
  --runtime python \
  --runtime-version 3.9 \
  --functions-version 4 \
  --name docling-ingest-func \
  --storage-account doclingingeststorage \
  --os-type Linux

# Deploy function code
func azure functionapp publish docling-ingest-func
```

### Option 2: Using VS Code

1. Install the **Azure Functions extension**
2. Open the project in VS Code
3. Click the Azure icon in the sidebar
4. Sign in to Azure
5. Right-click on your subscription → Create Function App in Azure
6. Follow the prompts to create and deploy

### Configure Application Settings

After deployment, add your environment variables as Application Settings:

```bash
az functionapp config appsettings set \
  --name docling-ingest-func \
  --resource-group docling-ingest-rg \
  --settings \
    SHAREPOINT_TENANT_ID=your-tenant-id \
    SHAREPOINT_CLIENT_ID=your-client-id \
    SHAREPOINT_CLIENT_SECRET=your-client-secret \
    SHAREPOINT_SITE_URL=your-site-url \
    SHAREPOINT_FOLDER_PATH="Shared Documents/PDFs" \
    VOYAGE_API_KEY=your-voyage-key \
    MONGODB_URI=your-mongodb-uri \
    MONGODB_DB=docling_ingestion \
    MONGODB_COLLECTION=pdf_chunks
```

**🔒 Security Note:** Application Settings in Azure Functions are stored securely and encrypted at rest.

## GitHub Actions CI/CD

### Setup GitHub Secrets

To enable automated deployments with GitHub Actions, configure the following secrets in your repository:

1. **Navigate to** Settings → Secrets and variables → Actions
2. **Add the following secrets:**

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` | Deployment credentials | Download from Azure Portal: Function App → Get publish profile |
| `SHAREPOINT_TENANT_ID` | Azure AD tenant ID | Azure Portal → Azure AD → Overview |
| `SHAREPOINT_CLIENT_ID` | App registration client ID | Azure Portal → App registrations → Your app |
| `SHAREPOINT_CLIENT_SECRET` | App client secret | Azure Portal → App registrations → Certificates & secrets |
| `SHAREPOINT_SITE_URL` | SharePoint site URL | https://yourtenant.sharepoint.com/sites/yoursite |
| `VOYAGE_API_KEY` | VoyageAI API key | https://voyage.ai dashboard |
| `MONGODB_URI` | MongoDB connection string | MongoDB Atlas → Connect → Connection string |

### Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Azure Functions

on:
  push:
    branches:
      - main
  workflow_dispatch:

env:
  AZURE_FUNCTIONAPP_NAME: docling-ingest-func
  AZURE_FUNCTIONAPP_PACKAGE_PATH: '.'
  PYTHON_VERSION: '3.9'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt --target=".python_packages/lib/site-packages"

      - name: Deploy to Azure Functions
        uses: Azure/functions-action@v1
        with:
          app-name: ${{ env.AZURE_FUNCTIONAPP_NAME }}
          package: ${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}
          publish-profile: ${{ secrets.AZURE_FUNCTIONAPP_PUBLISH_PROFILE }}

      - name: Configure Application Settings
        uses: azure/CLI@v1
        with:
          inlineScript: |
            az functionapp config appsettings set \
              --name ${{ env.AZURE_FUNCTIONAPP_NAME }} \
              --resource-group docling-ingest-rg \
              --settings \
                SHAREPOINT_TENANT_ID=${{ secrets.SHAREPOINT_TENANT_ID }} \
                SHAREPOINT_CLIENT_ID=${{ secrets.SHAREPOINT_CLIENT_ID }} \
                SHAREPOINT_CLIENT_SECRET=${{ secrets.SHAREPOINT_CLIENT_SECRET }} \
                SHAREPOINT_SITE_URL=${{ secrets.SHAREPOINT_SITE_URL }} \
                VOYAGE_API_KEY=${{ secrets.VOYAGE_API_KEY }} \
                MONGODB_URI=${{ secrets.MONGODB_URI }} \
                MONGODB_DB=docling_ingestion \
                MONGODB_COLLECTION=pdf_chunks
```

### Avoiding .env Files in Production

**Best Practice:** Never commit `.env` files to version control. Instead:

1. **Local Development:** Use `.env` file (already in `.gitignore`)
2. **Azure Functions:** Use Application Settings (configured via Azure Portal or CLI)
3. **GitHub Actions:** Use GitHub Secrets (configured in repository settings)

This ensures:
- ✅ Secrets are never exposed in code
- ✅ Different environments use different credentials
- ✅ Secrets can be rotated without code changes
- ✅ Compliance with security best practices

## Security Best Practices

### Preventing Secrets Leakage

1. **Never commit `.env`** - Already included in `.gitignore`
2. **Use Key Vault for production** - Azure Key Vault references in Application Settings
3. **Rotate credentials regularly** - Especially SharePoint client secrets
4. **Limit permissions** - Use least-privilege principle for app registrations
5. **Enable managed identities** - For Azure-to-Azure authentication (future enhancement)

### Example: Using Azure Key Vault

```bash
# Create Key Vault
az keyvault create --name docling-ingest-kv --resource-group docling-ingest-rg

# Store secrets
az keyvault secret set --vault-name docling-ingest-kv --name VoyageApiKey --value your-key

# Reference in Function App
az functionapp config appsettings set \
  --name docling-ingest-func \
  --resource-group docling-ingest-rg \
  --settings VOYAGE_API_KEY="@Microsoft.KeyVault(SecretUri=https://docling-ingest-kv.vault.azure.net/secrets/VoyageApiKey/)"
```

## API Reference

### POST /api/ingest_sharepoint_folder

Process all PDF files in a SharePoint folder.

**Request Body:**
```json
{
  "folder_path": "Shared Documents/PDFs",
  "max_files": 10
}
```

**Response:**
```json
{
  "status": "success",
  "processed": 5,
  "results": [
    {
      "doc_id": "technical-manual-a1b2c3d4",
      "chunk_count": 15,
      "figure_count": 8,
      "source_file": "technical-manual.pdf",
      "strategy": "docling"
    }
  ]
}
```

### POST /api/ingest_single_pdf

Process a single PDF file.

**Request Body (SharePoint):**
```json
{
  "source_type": "sharepoint",
  "file_name": "document.pdf",
  "folder_path": "Shared Documents/PDFs"
}
```

**Request Body (Blob Storage):**
```json
{
  "source_type": "blob",
  "container_name": "pdfs",
  "blob_name": "document.pdf"
}
```

### GET /api/health

Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "docling-ingest"
}
```

## Troubleshooting

### Common Issues

**Error: "Failed to acquire token"**
- Verify `SHAREPOINT_TENANT_ID`, `SHAREPOINT_CLIENT_ID`, and `SHAREPOINT_CLIENT_SECRET`
- Check that admin consent was granted for API permissions

**Error: "No drives found in SharePoint site"**
- Verify `SHAREPOINT_SITE_URL` is correct
- Ensure the app has `Sites.Read.All` permission

**Error: "File not found in folder"**
- Check `SHAREPOINT_FOLDER_PATH` format (e.g., "Shared Documents/PDFs")
- Verify the PDF files exist in the specified folder

**Error: "VOYAGE_API_KEY must be set"**
- Add your VoyageAI API key to environment variables
- Get a key from https://voyage.ai

**Error: "Failed to connect to MongoDB"**
- Verify `MONGODB_URI` connection string
- Check network access in MongoDB Atlas (whitelist Azure IPs or use 0.0.0.0/0)

### Enable Debug Logging

Add to your `.env`:
```bash
DEBUG_CHUNK_IMGS=true
FUNCTIONS_WORKER_RUNTIME=python
AZURE_FUNCTIONS_ENVIRONMENT=Development
```

## Project Structure

```
docling-ingest-boilerplate/
├── function_app.py              # Main Azure Functions app
├── utils/
│   ├── __init__.py
│   └── document_processing.py   # Extracted notebook utilities
├── requirements.txt             # Python dependencies
├── .env.example                 # Environment variable template
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── BroenBot-Ingest-binary.ipynb # Original Jupyter notebook (reference)
└── .github/
    └── workflows/
        └── deploy.yml           # CI/CD pipeline
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

See [LICENSE](LICENSE) file for details.

## Resources

- [Docling Documentation](https://github.com/DS4SD/docling)
- [Azure Functions Python Developer Guide](https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Microsoft Graph API Documentation](https://learn.microsoft.com/en-us/graph/overview)
- [VoyageAI API Documentation](https://docs.voyage.ai)
- [MongoDB Atlas Vector Search](https://www.mongodb.com/docs/atlas/atlas-vector-search/vector-search-overview/)

## Support

For issues or questions:
- Open an issue on GitHub
- Check the troubleshooting section above
- Review Azure Functions logs: `func azure functionapp logstream docling-ingest-func`
