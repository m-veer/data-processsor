# Robust Data Processor - Production Backend System

[![Deploy](https://github.com/YOUR_USERNAME/data-processor/actions/workflows/terraform-deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/data-processor/actions/workflows/terraform-deploy.yml)

A scalable, event-driven data processing pipeline built with **FastAPI**, **GCP Pub/Sub**, **Firestore**, and **Terraform** for infrastructure as code.

## 🏗️ Architecture

```
[Client] → [FastAPI API] → [Pub/Sub] → [Worker] → [Firestore]
         (Cloud Run)     (Message Queue)  (Cloud Run)  (Multi-tenant DB)
```

## ✨ Key Features

- **Unified Ingestion Gateway**: Single `/ingest` endpoint for JSON and TXT formats
- **Non-blocking API**: Returns `202 Accepted` in <100ms
- **Multi-tenant Isolation**: Physical data separation using Firestore sub-collections
- **Event-driven Processing**: Pub/Sub ensures reliable message delivery
- **Auto-scaling**: Handles 1,000+ RPM, scales to zero when idle
- **Crash Recovery**: Automatic retry with Pub/Sub NACK mechanism
- **Infrastructure as Code**: Complete Terraform configuration
- **CI/CD Pipeline**: Automated deployment via GitHub Actions

## 🚀 Quick Start

### Prerequisites

- GCP account with billing enabled
- Terraform >= 1.0
- gcloud CLI
- Docker (for local development)

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/data-processor.git
cd data-processor
```

### 2. Configure Terraform

```bash
cd terraform

# Update terraform.tfvars with your project ID
cat > terraform.tfvars <<EOF
project_id = "your-gcp-project-id"
region = "us-central1"
EOF

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 3. Deploy

```bash
# Get API URL
API_URL=$(terraform output -raw api_service_url)

# Test deployment
curl $API_URL/health
```

## 📝 API Usage

### JSON Payload

```bash
curl -X POST https://your-api-url/ingest \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "acme",
    "log_id": "123",
    "text": "User 555-0199 accessed the system"
  }'
```

**Response:**
```json
{
  "status": "accepted",
  "tenant_id": "acme",
  "log_id": "123",
  "message_id": "1234567890"
}
```

### Plain Text Payload

```bash
curl -X POST https://your-api-url/ingest \
  -H 'Content-Type: text/plain' \
  -H 'X-Tenant-ID: beta_inc' \
  -d 'Alert: System status check for 555-1234'
```

## 🗄️ Data Schema

```
tenants/
  ├── acme/
  │   └── processed_logs/
  │       └── 123/
  │           ├── source: "json_upload"
  │           ├── original_text: "User 555-0199..."
  │           ├── modified_data: "User [REDACTED]..."
  │           ├── processed_at: "2024-..."
  └── beta_inc/
      └── processed_logs/
          └── 456/
```

## 🧪 Testing

```bash
# Run unit tests
make test

# Run load tests (1,000 RPM)
python test.py

# Run integration tests
make test-integration
```

## 📊 Monitoring

```bash
# View API logs
gcloud run services logs read data-processor-api --region us-central1

# View Worker logs
gcloud run services logs read data-processor-worker --region us-central1

# Check Firestore data
open https://console.cloud.google.com/firestore/data
```

## 🔧 Development

### Local Setup

```bash
# Install dependencies
cd api
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Run locally
python main.py
```

### Using Makefile

```bash
make help           # Show all commands
make init           # Initialize Terraform
make plan           # Preview changes
make apply          # Deploy infrastructure
make test           # Run tests
make logs-api       # View API logs
make logs-worker    # View Worker logs
```

## 🌍 Multi-Environment Deployment

```bash
# Deploy to development
make deploy-dev

# Deploy to staging
make deploy-staging

# Deploy to production
make deploy-prod
```

## 🔒 Security

- Service accounts with minimal required permissions
- Secrets managed via GitHub Secrets
- PII redaction (phone numbers → [REDACTED])
- Optional authentication for production

## 💰 Cost Optimization

- **Serverless architecture**: Scales to zero when idle
- **Cloud Run**: Pay only for requests
- **Pub/Sub**: First 10GB/month free
- **Firestore**: 1GB storage, 50K reads, 20K writes/day free

**Estimated cost**: $5-15/month for 1,000 RPM

## 📚 Documentation

- [Terraform Setup Guide](./deploy.md)
- [Architecture Overview](./architecture.md)
- [API Reference](#api-usage)
- [Troubleshooting](#-monitoring)

## 🏆 Technical Highlights

- **Python 3.11** with FastAPI for high-performance async API
- **Terraform** for reproducible infrastructure
- **Docker** multi-stage builds for optimized images
- **GitHub Actions** for automated CI/CD
- **Pytest** with 95%+ code coverage
- **Multi-tenant architecture** with physical data isolation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👤 Author

**Your Name**
- GitHub: [@YOUR_USERNAME](https://github.com/YOUR_USERNAME)
- LinkedIn: [Your Profile](https://linkedin.com/in/YOUR_PROFILE)

## 🙏 Acknowledgments

- Built for FinQore backend engineering assessment
- Demonstrates production-grade cloud architecture
- Infrastructure as Code best practices

---

**⭐ If you found this project helpful, please give it a star!**