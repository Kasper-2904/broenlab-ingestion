# Azure Functions Python container with Docling
FROM mcr.microsoft.com/azure-functions/python:4-python3.11

# Set environment variables
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    PYTHONUNBUFFERED=1 \
    AzureWebJobsFeatureFlags=EnableWorkerIndexing

# Install CPU-only torch first (smaller than GPU version)
RUN pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Copy requirements and install
COPY requirements.txt /home/site/wwwroot/
RUN pip install -r /home/site/wwwroot/requirements.txt

# Copy application code
COPY . /home/site/wwwroot/
