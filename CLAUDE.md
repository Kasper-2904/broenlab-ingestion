# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

Azure Container App that ingests PDF documents from SharePoint, processes them with Docling, generates embeddings with VoyageAI, and stores chunks in MongoDB Atlas for RAG (Retrieval-Augmented Generation).

**Architecture:**
```
SharePoint Folder → n8n (polls every 5 min) → Azure Container App → MongoDB Atlas
```

**Key Components:**
- **Azure Container App**: `docling-ingest` in resource group `rg-broen-lab-ingestion`
- **Azure Container Registry**: `broenlabing.azurecr.io`
- **MongoDB Atlas**: `testCluster` → `broen-ingestion-test` → `broen-documents-test`
- **n8n**: Workflow polls SharePoint and triggers ingestion via HTTP

## Development Commands

### Local Setup
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Build and Deploy
```bash
# In Azure Cloud Shell
cd ~/broenlab-ingestion
git pull origin main
az acr build --registry broenlabing --image docling-ingest:vX .
az containerapp update --name docling-ingest --resource-group rg-broen-lab-ingestion --image broenlabing.azurecr.io/docling-ingest:vX
```

### Test Health Endpoint
```bash
curl https://docling-ingest.thankfulbush-dcd4f38d.swedencentral.azurecontainerapps.io/api/health
```

## Environment Variables (Azure Container App)

Required environment variables configured in Azure:
- `SHAREPOINT_TENANT_ID` - Azure AD tenant ID
- `SHAREPOINT_CLIENT_ID` - App registration client ID
- `SHAREPOINT_CLIENT_SECRET` - App registration secret
- `SHAREPOINT_SITE_URL` - e.g., `https://tenant.sharepoint.com/sites/SiteName`
- `SHAREPOINT_FOLDER_PATH` - e.g., `Shared Documents/PDFs`
- `VOYAGE_API_KEY` - VoyageAI API key
- `MONGODB_URI` - MongoDB Atlas connection string
- `MONGODB_DB` - Database name (e.g., `broen-ingestion-test`)
- `MONGODB_COLLECTION` - Collection name (e.g., `broen-documents-test`)
- `API_SECRET_KEY` - API key for authenticating n8n requests

## API Endpoints

### GET /api/health
Health check endpoint (no authentication required).

### POST /api/ingest_single_pdf
Ingest a single PDF from SharePoint.

**Headers:**
- `X-API-Key`: API secret key

**Body:**
```json
{
  "source_type": "sharepoint",
  "file_name": "document.pdf",
  "folder_path": "BroenTest"
}
```

### POST /api/ingest_sharepoint_folder
Ingest all PDFs from a SharePoint folder.

**Headers:**
- `X-API-Key`: API secret key

**Body:**
```json
{
  "folder_path": "Shared Documents/PDFs",
  "max_files": 10
}
```

## Key Design Decisions

### Content-Based Document IDs
Document IDs are generated from SHA256 hash of PDF content (not filename). This means:
- Same content = same doc_id (updates existing) regardless of filename
- Different content = new doc_id (creates new documents)
- Renaming a file won't create duplicates

### Upsert Logic
Documents are upserted based on `chunk_id`. Re-processing a PDF updates existing chunks instead of creating duplicates.

### Scale-to-Zero
Container App scales to zero when not in use. Only runs when n8n triggers it, keeping costs under $5/month.

### Chunking Strategy
PDFs are split into chunks (~768 tokens) using Docling's HybridChunker for optimal RAG retrieval. Each chunk stored as separate MongoDB document with its own embedding.

## File Structure

```
├── function_app.py          # Main Azure Functions code with HTTP triggers
├── utils/
│   ├── __init__.py
│   └── document_processing.py  # Helper functions for chunking, embedding, persistence
├── Dockerfile               # Container image definition
├── requirements.txt         # Python dependencies
├── host.json               # Azure Functions host configuration
└── .env.example            # Environment variable template
```

## n8n Workflow

The n8n workflow (`mongoRAG-broen-ingestion.json`):
1. **Schedule Trigger**: Runs every 5 minutes
2. **SharePoint Config**: Sets Site/Drive/Folder IDs
3. **List SharePoint Files**: Calls Microsoft Graph API
4. **Filter Recent PDFs**: JavaScript node filters for new/modified PDFs in last 5 minutes
5. **Process PDF**: HTTP POST to Container App with API key header

## MongoDB Schema

Each chunk document contains:
```json
{
  "_id": "ObjectId",
  "chunk_id": "doc-name-hash::chunk-0001",
  "document_id": "doc-name-hash",
  "chunk_index": 0,
  "text": "Chunk text content...",
  "metadata": {
    "source_pdf": "/path/to/file.pdf",
    "pages": [1, 2],
    "headings": ["Section 1"],
    "figure_refs": [...]
  },
  "binary": {
    "figure-id": {
      "data": "base64...",
      "mimeType": "image/png",
      "fileName": "figure.png"
    }
  },
  "embedding": [0.123, 0.456, ...]  // 1024 dimensions
}
```

## Vector Search Index

MongoDB Atlas vector search index on `broen-documents-test`:
- Field: `embedding`
- Dimensions: 1024
- Similarity: cosine

## Troubleshooting

### 404 - Functions not found
Ensure `AzureWebJobsFeatureFlags=EnableWorkerIndexing` is set in Dockerfile ENV.

### 401 - MongoDB authentication failed
Check `MONGODB_URI` has correct username/password (URL-encode special characters).

### 401 - API key invalid
Verify `X-API-Key` header in n8n matches `API_SECRET_KEY` in Container App env vars.

### Connection refused to localhost:27017
`MONGODB_URI` not set or incorrect. Should be Atlas connection string, not localhost.

## Links

- **GitHub**: https://github.com/Kasper-2904/broenlab-ingestion
- **Container App URL**: https://docling-ingest.thankfulbush-dcd4f38d.swedencentral.azurecontainerapps.io
- **Azure Resource Group**: `rg-broen-lab-ingestion`
