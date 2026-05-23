import json
import boto3
import os
import re

sns = boto3.client('sns')

PLATFORM_APPLICATION_ARN = os.environ.get('PLATFORM_APPLICATION_ARN')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    try:
        # Handle both Lambda Proxy Integration and Non-Proxy Integration
        if 'body' in event and isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event

        fcm_token = body.get('token')

        if not fcm_token:
            return {
                'statusCode': 400,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Missing FCM token'})
            }

        endpoint_arn = None
        
        # 1. Create or get the Platform Endpoint
        try:
            response = sns.create_platform_endpoint(
                PlatformApplicationArn=PLATFORM_APPLICATION_ARN,
                Token=fcm_token,
                Attributes={'Enabled': 'true'}
            )
            endpoint_arn = response['EndpointArn']
        except Exception as e:
            error_message = str(e)
            # AWS SNS throws a specific error if the endpoint exists but has different attributes (e.g. disabled)
            if "Endpoint" in error_message and "already exists" in error_message:
                match = re.search(r'Endpoint (.+?) already exists', error_message)
                if match:
                    endpoint_arn = match.group(1)
                    # Re-enable the endpoint and update the token
                    sns.set_endpoint_attributes(
                        EndpointArn=endpoint_arn,
                        Attributes={
                            'Token': fcm_token,
                            'Enabled': 'true'
                        }
                    )
            else:
                raise e

        # 2. Subscribe the Endpoint to the Topic
        if endpoint_arn:
            sns.subscribe(
                TopicArn=SNS_TOPIC_ARN,
                Protocol='application',
                Endpoint=endpoint_arn
            )

        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'message': 'Device successfully registered for push notifications',
                'endpoint_arn': endpoint_arn
            })
        }

    except Exception as e:
        print(f"Error registering device: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': 'Internal Server Error', 'details': str(e)})
        }
