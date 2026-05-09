import boto3
import json
import boto3
import os
from datetime import datetime


#https://0vqf7cd4q5.execute-api.us-east-1.amazonaws.com/approve/upload/approve

s3 = boto3.client('s3')
rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')

BUCKET_NAME = os.environ.get('BUCKET_NAME')
COLLECTION_ID = os.environ.get('COLLECTION_ID')
TABLE_USER_NAME = os.environ.get('TABLE_USER_NAME')
TABLE_EVENT_NAME = os.environ.get('TABLE_EVENT_NAME')

def lambda_handler(event, context):
    try:
        # Handle both Lambda Proxy Integration and Non-Proxy Integration
        if 'body' in event and isinstance(event['body'], str):
            body = json.loads(event['body'])
        else:
            body = event

        event_id = body.get('event_id')
        user_name = body.get('user_name')
        user_role = body.get('user_role', 'Undefined')

        if not event_id or not user_name:
            return {
                'statusCode': 400,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Missing event_id or user_name'})
            }
        

        events_table = dynamodb.Table(TABLE_EVENT_NAME)
        users_table = dynamodb.Table(TABLE_USER_NAME)
        timestamp = datetime.utcnow().isoformat()
        
        event_response = events_table.get_item(Key={'EventID': event_id})
        if 'Item' not in event_response:
            return {
                'statusCode': 404,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'error': 'Event not found'})
            }
        
        image_key = event_response['Item']['S3_EventImagePath']

        # Index the new face id
        index_response =rekognition.index_faces(
            CollectionId=COLLECTION_ID,
            Image={'S3Object': {'Bucket': BUCKET_NAME, 'Name': image_key}}, 
            ExternalImageId=user_name.replace(' ', '_'),
            MaxFaces=1,
            QualityFilter='AUTO'
        )

        if not index_response.get('FaceRecords'):
            # return {
            #     'statusCode': 400,
            #     'headers': {'Access-Control-Allow-Origin': '*'},
            #     'body': json.dumps({'error': 'Failed to index face'})
            # }
            new_face_id="Unknown"
        # Get the new face id
        else:
            new_face_id = index_response['FaceRecords'][0]['Face']['FaceId']
        
        # Add the new face id to the users table
            users_table.put_item(
                Item={
                    'FaceID': new_face_id,
                    'Name': user_name,
                    'Role': user_role,
                    'CreatedAt': timestamp,
                    'S3_ProfilePicturePath': image_key
                }
            )
        # Update the event status to recognized and add the new face id
        events_table.update_item(
            Key={'EventID': event_id},
            UpdateExpression='SET #s = :status, FaceID = :face_id, Confidence = :confidence',
            ExpressionAttributeNames={
                '#s': 'Status'
            },
            ExpressionAttributeValues={
                ':status': 'Recognized',
                ':face_id': new_face_id,
                ':confidence': '1.0'
            }
        )

        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({
                'message': 'User approved successfully',
                'status': 'Recognized',
                'face_id': new_face_id,
                'user_name': user_name,
                'confidence': '1.0'
            })
        }

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'Internal Server Error': str(e)})
        }

        
        
        
