#!/usr/bin/env python3
"""
Local test script for Lambda handler
Run this to test the Lambda handler locally before deploying
"""

import json
from lambda_handler import handler

# Mock Lambda context
class MockContext:
    def __init__(self):
        self.function_name = "langchain-sql-query"
        self.function_version = "$LATEST"
        self.invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:langchain-sql-query"
        self.memory_limit_in_mb = 512
        self.aws_request_id = "test-request-id"
        self.log_group_name = "/aws/lambda/langchain-sql-query"
        self.log_stream_name = "test-stream"

def test_lambda_handler():
    """Test the Lambda handler with sample events"""

    print("=" * 60)
    print("Testing Lambda Handler Locally")
    print("=" * 60)

    # Test 1: Valid query with API Gateway event format
    print("\nTest 1: Valid query (API Gateway format)")
    print("-" * 60)
    event = {
        "body": json.dumps({"query": "How many customers are there?"}),
        "headers": {"Content-Type": "application/json"}
    }

    context = MockContext()
    response = handler(event, context)

    print(f"Status Code: {response['statusCode']}")
    print(f"Response Body: {response['body']}")

    # Test 2: Direct Lambda invocation format
    print("\nTest 2: Valid query (Direct invocation)")
    print("-" * 60)
    event = {
        "query": "What are the names of all artists?"
    }

    response = handler(event, context)
    print(f"Status Code: {response['statusCode']}")
    print(f"Response Body: {response['body']}")

    # Test 3: Missing query field
    print("\nTest 3: Missing query field (Error case)")
    print("-" * 60)
    event = {
        "body": json.dumps({"wrong_field": "test"})
    }

    response = handler(event, context)
    print(f"Status Code: {response['statusCode']}")
    print(f"Response Body: {response['body']}")

    # Test 4: Invalid JSON
    print("\nTest 4: Invalid JSON (Error case)")
    print("-" * 60)
    event = {
        "body": "not valid json"
    }

    response = handler(event, context)
    print(f"Status Code: {response['statusCode']}")
    print(f"Response Body: {response['body']}")

    print("\n" + "=" * 60)
    print("Testing Complete!")
    print("=" * 60)

if __name__ == "__main__":
    import os

    # Check for OPENAI_API_KEY
    if not os.getenv("OPENAI_API_KEY"):
        print("WARNING: OPENAI_API_KEY not set in environment")
        print("Set it with: export OPENAI_API_KEY='your-key'")
        exit(1)

    test_lambda_handler()
