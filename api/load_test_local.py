#!/usr/bin/env python3
"""
Load test with mixed JSON and TXT requests
Tests both Scenario 1 (JSON) and Scenario 2 (TXT) from requirements
"""

import requests
import time
import uuid
import random
from concurrent.futures import ThreadPoolExecutor
from statistics import mean, median

# API_URL = "http://localhost:8080"
API_URL = "https://data-processor-api-x7e7c5blga-uc.a.run.app"
TOTAL_REQUESTS = 1000
CONCURRENT = 50

results = {
    "json_success": 0,
    "json_failed": 0,
    "txt_success": 0,
    "txt_failed": 0,
    "json_times": [],
    "txt_times": [],
    "all_times": []
}

# Sample log messages for variety
SAMPLE_LOGS = [
    "User 555-0199 accessed the system from IP 192.168.1.1",
    "Error occurred in module payment_processor with code 555-1234",
    "Transaction completed for account ending in 555-9876 amount $1,234.56",
    "Login attempt detected from phone 555-5555 at location NYC",
    "System backup completed successfully - 2.5GB transferred",
    "Database query executed in 850ms for user 555-7890",
    "Security alert: Multiple failed login attempts from 555-4321",
    "Report generated with 10,000 records for tenant analysis",
    "API rate limit warning: 555-8888 exceeded threshold",
    "Cache invalidated for user session 555-3456"
]

def send_json_request(i):
    """Send JSON request (Scenario 1)"""
    try:
        start = time.time()
        r = requests.post(
            f"{API_URL}/ingest",
            json={
                "tenant_id": f"tenant_json_{i % 10}",
                "log_id": f"json_{uuid.uuid4()}",
                "text": f"{random.choice(SAMPLE_LOGS)} - Request #{i}"
            },
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        duration = time.time() - start
        
        if r.status_code == 202:
            results["json_success"] += 1
            results["json_times"].append(duration)
            results["all_times"].append(duration)
        else:
            results["json_failed"] += 1
            print(f"JSON request {i} failed with status {r.status_code}")
            
    except Exception as e:
        results["json_failed"] += 1
        print(f"JSON request {i} error: {type(e).__name__}")


def send_txt_request(i):
    """Send TXT request (Scenario 2)"""
    try:
        start = time.time()
        
        # Raw text payload
        text_data = f"{random.choice(SAMPLE_LOGS)} - TXT Request #{i}"
        
        r = requests.post(
            f"{API_URL}/ingest",
            data=text_data,
            headers={
                "Content-Type": "text/plain",
                "X-Tenant-ID": f"tenant_txt_{i % 10}"
            },
            timeout=10
        )
        duration = time.time() - start
        
        if r.status_code == 202:
            results["txt_success"] += 1
            results["txt_times"].append(duration)
            results["all_times"].append(duration)
        else:
            results["txt_failed"] += 1
            print(f"TXT request {i} failed with status {r.status_code}")
            
    except Exception as e:
        results["txt_failed"] += 1
        print(f"TXT request {i} error: {type(e).__name__}")


def send_request(i):
    """Send either JSON or TXT request (50/50 split)"""
    if i % 2 == 0:
        send_json_request(i)
    else:
        send_txt_request(i)


print("=" * 70)
print("🔥 MIXED LOAD TEST - JSON + TXT Requests")
print("=" * 70)
print(f"API URL:       {API_URL}")
print(f"Total Reqs:    {TOTAL_REQUESTS}")
print(f"Concurrent:    {CONCURRENT}")
print(f"Split:         50% JSON | 50% TXT")
print(f"Timeout:       10 seconds")
print("=" * 70)
print()

# Warm up the service
print("🔥 Warming up API...")
try:
    requests.get(f"{API_URL}/health", timeout=5)
    print("✓ Warmup complete\n")
except:
    print("⚠ Warmup failed, proceeding anyway\n")

start_time = time.time()

# Run load test
with ThreadPoolExecutor(max_workers=CONCURRENT) as executor:
    list(executor.map(send_request, range(TOTAL_REQUESTS)))

total_time = time.time() - start_time

# Calculate statistics
total_success = results["json_success"] + results["txt_success"]
total_failed = results["json_failed"] + results["txt_failed"]
json_total = results["json_success"] + results["json_failed"]
txt_total = results["txt_success"] + results["txt_failed"]

print("\n" + "=" * 70)
print("📊 LOAD TEST RESULTS")
print("=" * 70)

# Overall stats
print(f"\n{'OVERALL STATISTICS':^70}")
print("-" * 70)
print(f"Total Requests:        {TOTAL_REQUESTS}")
print(f"Successful:            {total_success} ({total_success/TOTAL_REQUESTS*100:.1f}%)")
print(f"Failed:                {total_failed}")
print(f"Total Time:            {total_time:.2f}s")
print(f"Requests/Second:       {TOTAL_REQUESTS/total_time:.2f}")
print(f"Requests/Minute:       {TOTAL_REQUESTS/total_time*60:.0f}")

# JSON-specific stats
print(f"\n{'JSON REQUESTS (Scenario 1)':^70}")
print("-" * 70)
print(f"Total JSON Requests:   {json_total}")
print(f"Successful:            {results['json_success']} ({results['json_success']/json_total*100:.1f}%)")
print(f"Failed:                {results['json_failed']}")
if results['json_times']:
    print(f"Avg Response Time:     {mean(results['json_times'])*1000:.2f}ms")
    print(f"Median Response Time:  {median(results['json_times'])*1000:.2f}ms")

# TXT-specific stats
print(f"\n{'TXT REQUESTS (Scenario 2)':^70}")
print("-" * 70)
print(f"Total TXT Requests:    {txt_total}")
print(f"Successful:            {results['txt_success']} ({results['txt_success']/txt_total*100:.1f}%)")
print(f"Failed:                {results['txt_failed']}")
if results['txt_times']:
    print(f"Avg Response Time:     {mean(results['txt_times'])*1000:.2f}ms")
    print(f"Median Response Time:  {median(results['txt_times'])*1000:.2f}ms")

# Combined response time stats
if results['all_times']:
    sorted_times = sorted(results['all_times'])
    p95_idx = int(len(sorted_times) * 0.95)
    p99_idx = int(len(sorted_times) * 0.99)
    
    print(f"\n{'RESPONSE TIME STATISTICS (ALL REQUESTS)':^70}")
    print("-" * 70)
    print(f"Average:               {mean(results['all_times'])*1000:.2f}ms")
    print(f"Median:                {median(results['all_times'])*1000:.2f}ms")
    print(f"Min:                   {min(results['all_times'])*1000:.2f}ms")
    print(f"Max:                   {max(results['all_times'])*1000:.2f}ms")
    print(f"95th Percentile:       {sorted_times[p95_idx]*1000:.2f}ms")
    print(f"99th Percentile:       {sorted_times[p99_idx]*1000:.2f}ms")

print("\n" + "=" * 70)

# Performance assessment
if total_success >= TOTAL_REQUESTS * 0.95:
    print("✅ TEST PASSED (≥95% success rate)")
else:
    print("❌ TEST FAILED (<95% success rate)")

# Detailed assessment
avg_ms = mean(results['all_times']) * 1000 if results['all_times'] else 0
if avg_ms < 200:
    print("🚀 PERFORMANCE: EXCELLENT (Avg < 200ms)")
elif avg_ms < 500:
    print("✅ PERFORMANCE: GOOD (Avg < 500ms)")
elif avg_ms < 1000:
    print("⚠️  PERFORMANCE: ACCEPTABLE (Avg < 1s)")
else:
    print("⚠️  PERFORMANCE: SLOW (Avg > 1s - expected for cold start)")

print("=" * 70)