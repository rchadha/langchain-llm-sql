import json
import os
from langchain_llm_sql import query_database

def handler(event, context):
    """
    AWS Lambda handler function for processing SQL queries via API Gateway

    Args:
        event: API Gateway event containing the request
        context: Lambda context object

    Returns:
        API Gateway response with query results
    """
    try:
        # Parse the request body
        if 'body' in event:
            # Handle API Gateway proxy integration
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            # Handle direct Lambda invocation
            body = event

        # Validate input
        if 'query' not in body:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'OPTIONS,POST'
                },
                'body': json.dumps({'error': 'Invalid input: query field is required'})
            }

        query_string = body['query']

        # Execute the query
        result = query_database(query_string)

        if result is None:
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Query failed'})
            }

        # Return successful response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            },
            'body': json.dumps({'result': result})
        }

    except json.JSONDecodeError as e:
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': f'Invalid JSON: {str(e)}'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': f'An error occurred: {str(e)}'})
        }
