#!/bin/bash
set -e

source worker/venv/bin/activate

echo "🔧 Installing tools..."
pip install black isort flake8 pytest httpx google google-cloud-pubsub==2.18.4 google-cloud-firestore==2.13.1 -q

echo "📝 Formatting code with Black..."
black api/ worker/

echo "📋 Sorting imports with isort..."
isort api/ worker/ --profile black

echo "✅ Verifying formatting..."
black --check api/ worker/ && echo "  ✓ Black formatting OK"
isort --check-only api/ worker/ && echo "  ✓ Import sorting OK"

echo ""
echo "🧪 Testing locally..."
cd api
pytest tests/ -v -q && echo "  ✓ API tests pass"
cd ../worker
pytest tests/ -v -q && echo "  ✓ Worker tests pass"
cd ..

echo ""
echo "🎉 Done! Check GitHub Actions"