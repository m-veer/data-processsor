# 🧰 Data Processor

**Event-driven, cloud-native log ingestion pipeline on Google Cloud**

Data Processor is a production-style reference project that shows how to build a **fully automated ingestion and processing system** on **Cloud Run, Pub/Sub, Firestore, and Terraform**, wired up with **GitHub Actions CI/CD**.

It consists of:

- **API Service (Cloud Run + FastAPI)** – receives JSON or text logs, normalizes them, and publishes to Pub/Sub.
- **Worker Service (Cloud Run)** – subscribes to Pub/Sub, simulates heavy processing, performs PII redaction, and stores results in Firestore with strict multi-tenant isolation.

---

## ⚡ Quick Start (3 Steps)

> Best for just seeing everything run end-to-end in your own GCP project.

1. **Clone the repo & set env**
   ```bash
   git clone https://github.com/m-veer/data-processor.git
   cd data-processor

   # Create .env at repo root
   cat > .env << EOF
   GCP_PROJECT_ID=your-project-id
   GCP_REGION=us-central1
   EOF

2. Provision infra with Terraform
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

3. Trigger GitHub Actions deployment
- Push to a feature branch → open PR → PR validation runs.
- Merge to main → merge workflow builds Docker images, pushes to Artifact Registry, and deploys Cloud Run + Pub/Sub + Firestore via Terraform.
- Grab the API Cloud Run URL from the merge workflow summary and start ingesting logs.

📖 Introduction
This project is designed as a realistic backend / DevOps portfolio piece:
- Cloud-native, serverless-first architecture
- Infrastructure as Code with Terraform
- CI/CD via GitHub Actions
- Multi-tenant Firestore data model
- Built-in crash / retry / DLQ simulation for reliability demos

You get:
1. Unified ingestion endpoint for JSON & text logs
2. Asynchronous worker with PII redaction & heavy-processing simulation
3. Dead-Letter Queue (DLQ) routing using Pub/Sub delivery attempts

🏗 Architecture Overview
High-Level Flow

           ┌────────────────────────────┐
           │      Client / Postman      │
           └────────────┬───────────────┘
                        │  HTTPS /ingest
                        ▼
              ┌───────────────────────┐
              │  API Service (FastAPI)│  Cloud Run
              │  - JSON / text ingest │
              │  - Multi-tenant IDs   │
              └──────────┬────────────┘
                         │ Pub/Sub publish
                         ▼
           ┌──────────────────────────────┐
           │   Pub/Sub Topic              │
           │   data-ingestion             │
           └───────────┬──────────────────┘
                       │ subscription
                       ▼
          ┌───────────────────────────────┐
          │ Worker Service (Python)       │ Cloud Run
          │ - Simulated heavy processing  │
          │ - PII redaction               │
          │ - Crash + retry simulation    │
          └───────────┬───────────────────┘
                      │ Firestore write
                      ▼
         ┌──────────────────────────────────────┐
         │ Firestore                            │
         │ tenants/{tenant_id}/processed_logs/  │
         └──────────────────────────────────────┘

                 ▲
                 │  after N failed deliveries
                 │  (e.g. 20 attempts)
                 │
           ┌──────────────────────────────┐
           │ Pub/Sub DLQ Topic            │
           │ data-ingestion-dlq           │
           └──────────────────────────────┘

✨ Core Features

1️⃣ Unified Ingestion API
- OST /ingest
- Accepts:
    - application/json with tenant_id, optional log_id, text
    - text/plain with X-Tenant-ID header
- Normalizes all input into a single internal JSON structure and publishes to Pub/Sub.

2️⃣ Asynchronous Worker with Crash Simulation
- Subscribes to data-ingestion Pub/Sub topic.
- Simulates heavy processing (sleep based on text length).
- Redacts phone numbers from text (XXX-XXX-XXXX, XXX-XXXX, etc.).
- For messages containing crash_test, intentionally fails first 5 attempts, then succeeds using Pub/Sub’s delivery_attempt counter.
- Persists processed logs to Firestore:
    - tenants/{tenant_id}/processed_logs/{log_id}

3️⃣ Reliability with Dead-Letter Queue (DLQ)
- Terraform configures:
    - DLQ topic: data-ingestion-dlq
    - Subscription settings: max_delivery_attempts = 20
- Messages that keep failing (e.g., bugs, malformed data) are automatically moved to DLQ for inspection / replay.

🧰 Tech Stack
- Runtime & Services
    - Python (FastAPI + Pub/Sub client + Firestore client)
    - Google Cloud Run (API & Worker)
    - Google Pub/Sub (topic, subscription, DLQ)
    - Google Firestore (multi-tenant document storage)
    - Artifact Registry (Docker images)

- Infrastructure
    - Terraform (GCP provider)
    - Google Cloud IAM, service accounts
    - Terraform state backend in GCS

- CI/CD
    - GitHub Actions:
        - PR validation (pr-workflow.yml)
        - Image build & deploy (deploy-api.yml, deploy-worker.yml, merge-workflow.yml)
        - Infra deploy (terraform-deploy.yml)

- Local Tooling
  - docker-compose.local.yml
  - Makefile helpers
  - Shell scripts (format_check.sh, log_tail.sh, test_crash_recovery.sh, etc.)

📁 Project Structure
.
├── .github/
│   └── workflows/
│       ├── deploy-api.yml          # Deploy only API service
│       ├── deploy-worker.yml       # Deploy only Worker service
│       ├── deploy.yml              # Generic deploy workflow
│       ├── merge-workflow.yml      # Main branch: build & deploy infra + services
│       ├── pr-workflow.yml         # PR validation (tests, format, TF validate)
│       └── terraform-deploy.yml    # Terraform apply workflow
│
├── api/
│   ├── Dockerfile                  # API container image
│   ├── main.py                     # FastAPI app (Pub/Sub publisher + /ingest)
│   ├── load_test_local.py          # Local load testing helper
│   ├── run_local.py                # Run API locally with uvicorn
│   ├── requirements.txt            # API Python deps
│   ├── conftest.py                 # Pytest config
│   └── tests/
│       └── test_main.py            # API unit tests
│
├── worker/
│   ├── Dockerfile                  # Worker container image
│   ├── main.py                     # Pub/Sub subscriber + Firestore writer
│   ├── requirements.txt            # Worker Python deps
│   ├── conftest.py                 # Pytest config
│   └── tests/
│       └── test_main.py            # Worker unit tests
│
├── terraform/
│   ├── main.tf                     # Core infra: Run, Pub/Sub, Firestore, IAM
│   ├── variables.tf                # Terraform variables
│   ├── outputs.tf                  # Output URLs, IDs, etc.
│   ├── terraform.tfvars            # Project-specific values
│   ├── terraform.tfstate*          # Local state (if not remote)
│   ├── .terraform/                 # Terraform cache
│   ├── .terraform.lock.hcl         # Provider lock file
│   ├── environments/               # (Optional) extra env configs
│   ├── import_resources.sh         # Helper for importing existing GCP resources
│   └── tfplan                      # Saved TF plan (when used)
│
├── docker-compose.local.yml        # Local multi-service run config
├── format_check.sh                 # Local formatting helper
├── deploy.sh                       # Local deploy helper
├── rebuild_and_deploy.sh           # Local rebuild + deploy script
├── log_tail.sh                     # Tail Cloud Run logs helper
├── test_crash_recovery.sh          # Script to drive crash_test scenarios
│
├── architecture.md                 # Extended architecture notes
├── SETUP.md                        # Detailed setup instructions
├── TERRAFORM_SETUP.md              # Deep dive Terraform instructions
├── deploy.md                       # Deployment notes / runbook
│
├── Back End Interview.pdf          # Problem statement / interview brief
├── data-processor-480019-sa-key.json # (local) GCP SA key for testing
├── .env                            # Local environment variables
├── .gitignore
├── Makefile
├── README.md                       # You are here
└── Todo.txt                        # Future polish & task list

👨‍💻 New Developer Setup
This is the “I just joined the team, what do I do?” section.

1. Install prerequisites
- Python 3.11+
- Docker & Docker Compose
- Terraform ≥ 1.6
- gcloud CLI (with your GCP account authenticated)

2. Configure GCP project
- gcloud config set project <YOUR_PROJECT_ID>
- gcloud auth application-default login

3. Fill in Terraform variables
Edit terraform/terraform.tfvars (example):
- project_id        = "your-project-id"
- region            = "us-central1"
- api_image         = "us-central1-docker.pkg.dev/your-project-id/data-processor/data-processor-api:latest"
- worker_image      = "us-central1-docker.pkg.dev/your-project-id/data-processor/data-processor-worker:latest"
- firestore_db_name = "(default)"

4. Initialize & deploy infra
- cd terraform
- terraform init
- erraform plan -out=tfplan
- terraform apply tfplan

5. Let GitHub Actions manage deployments
- Configure repository secrets (service account JSON, project ID, region, etc.).
- Push feature branches → PR validation.
- Merge to main → automatic build & deploy.

6. Run tests locally
- # From repo root
- pytest api/tests
- pytest worker/tests

🧪 Local Development & Testing
- Run API locally
    - cd api
    - python -m venv venv
    - source venv/bin/activate
    - pip install -r requirements.txt
    - uvicorn main:app --reload --host 0.0.0.0 --port 8080

- Run Worker locally (against real Pub/Sub)
    - Make sure you have valid GCP credentials & env vars:
        - cd worker
        - python -m venv venv
        - source venv/bin/activate
        - pip install -r requirements.txt

        - export GCP_PROJECT_ID=<your-project-id>
        - export PUBSUB_SUBSCRIPTION_ID=data-ingestion-sub

        - python main.py

- Run everything with Docker Compose
    - docker-compose -f docker-compose.local.yml up --build

🌐 API Usage
1. JSON Ingestion
    - Request
        - POST /ingest HTTP/1.1
        - Content-Type: application/json

        - {
            "tenant_id": "abcd",
            "log_id": "test_012",
            "text": "Testing crash_test path with phone 555-0199"
        - }

    - Response
        - {
            "status": "accepted",
            "tenant_id": "abcd",
            "log_id": "test_012",
            "message_id": "17229986288873513",
            "message": "Data queued for processing"
        - }

2. Text Ingestion
    - Request
        - POST /ingest HTTP/1.1
        - Content-Type: text/plain
        - X-Tenant-ID: abcd

        - User 555-0199 accessed the system from IP 192.168.1.1 - TXT Request #1 - crash_test

    - Response
        - {
            "status": "accepted",
            "tenant_id": "abcd",
            "log_id": "bf4962a1-c55b-4dc4-b6a6-9476a27e16a2",
            "message_id": "17135587711641859",
            "message": "Data queued for processing"
        - }

🧹 PII Redaction
- worker/main.py uses redact_pii(text: str) -> str to scrub phone numbers.

Handled patterns include:
- XXX-XXX-XXXX → [REDACTED]
- XXX-XXXX → [REDACTED]

You can extend this function to cover:
- International formats (+1 (555) 123-4567)
- Email addresses
- Credit card patterns
- Custom tenant-specific rules

🔁 Crash Simulation & Recovery
- Messages whose text contains crash_test are treated specially:
delivery_attempt = message.delivery_attempt or 1

- if "crash_test" in text.lower():
      if delivery_attempt <= 5:
          # Simulate crash
          raise Exception(f"Simulated crash - Attempt {delivery_attempt}")
      else:
          # Finally succeed
          logger.info(f"✅ PASSED after {delivery_attempt} attempts")

- On each failure:
    - Worker logs the error
    - Calls message.nack() so Pub/Sub retries later
- On attempt 6+, processing proceeds normally:
    - Heavy processing simulation
    - PII redaction
    - Firestore write
    - message.ack()

- Testing crash scenarios
    - Use test_crash_recovery.sh (or Postman) to send payloads with crash_test and watch:
        - ./log_tail.sh worker   # Tail Cloud Run worker logs
        - ./test_crash_recovery.sh

☠️ Dead-Letter Queue (DLQ) Behavior
Terraform configures:
- google_pubsub_topic.data_ingestion_dlq (data-ingestion-dlq)
- google_pubsub_subscription.data_ingestion_sub with:
    - dead_letter_policy referencing DLQ topic
    - max_delivery_attempts = 20
- After 20 failed deliveries:
    - The message stops retrying on the main subscription.
    - It is sent to data-ingestion-dlq for inspection.

- You can pull DLQ messages with:
    - gcloud pubsub subscriptions pull data-ingestion-dlq-sub \
        --project=$PROJECT_ID \
        --auto-ack \
        --limit=10

🧱 Terraform Notes
- Initialize
    - cd terraform
    - terraform init
- Plan & Apply
    - terraform plan -out=tfplan \
      -var="project_id=<PROJECT_ID>" \
      -var="region=us-central1"
    - terraform apply tfplan

- Import Existing Resources
- If some resources were created manually (e.g. DLQ topic), import them:
    - terraform import \
        google_pubsub_topic.data_ingestion_dlq \
        "projects/<PROJECT_ID>/topics/data-ingestion-dlq"
- import_resources.sh contains helper commands you can adapt.

- For deeper details, see TERRAFORM_SETUP.md.

🚀 Future Scope
- Some planned / potential enhancements for this project:
- Platform & Architecture
    - Multi-region deployments with global load balancing for API and Worker.
    - BigQuery sink for analytical queries on processed logs.
    - Event versioning & schema registry (e.g., using JSON schema or Proto) to evolve message formats safely.
    - Config-driven PII redaction rules stored per tenant in Firestore or a config service.
    - Idempotent processing (e.g., dedupe by (tenant_id, log_id) with strong guarantees).
- Observability & Operations
    - End-to-end tracing using OpenTelemetry (API → Pub/Sub → Worker → Firestore).
    - Dashboards & alerts in Cloud Monitoring for:
        - Pub/Sub backlog
        - DLQ volume
        - Error rates per tenant
    - SLOs & error budgets (e.g., 99.9% successful processing within X minutes).
    - Admin tooling to replay DLQ messages back into the main topic.
- Security & Multi-Tenancy
    - Tenant-aware authentication & authorization (e.g., OAuth / API keys / mTLS).
    - Per-tenant quotas & rate limiting to isolate noisy neighbors.
    - Customer-managed encryption keys (CMEK) for regulatory use-cases.
    - Fine-grained Firestore security rules or access layer enforcing tenant isolation.
- Developer Experience
    - Local Pub/Sub & Firestore emulators wired into docker-compose.local.yml.
    - Smoke-test workflow that runs after every deploy using the real Cloud Run URL.
    - Scaffold scripts to create new environments (dev / staging / prod) from templates.
    - More test coverage for edge cases (PII patterns, DLQ routing, retry behavior).

🤝 Contributing
1. Fork the repository.
2. Create a feature branch:
    - git checkout -b feature/my-change
3. Run tests and formatters locally:
    - pytest api/tests worker/tests
    - ./format_check.sh
4. Push and open a Pull Request.

- PRs automatically run the PR validation workflow (tests + Terraform checks).

👤 Author
- Mayur Veer
    - GitHub: @m-veer
    - LinkedIn: linkedin.com/in/mayur-veer

<div align="center">
Built as a production-style backend & DevOps showcase.
Logs in, insights out.
</div> ``` ::contentReference[oaicite:0]{index=0}