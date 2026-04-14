import json
import boto3
import base64
import os
from datetime import datetime

s3 = boto3.client('s3')
rekognition = boto3.client('rekognition')
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

BUCKET_NAME = os.environ.get('BUCKET_NAME')
COLLECTION_ID = os.environ.get('COLLECTION_ID')
TABLE_USER_NAME = os.environ.get('TABLE_USER_NAME') # the userid is the faceid
TABLE_EVENT_NAME = os.environ.get('TABLE_EVENT_NAME')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN') 

def lambda_handler(event, context):
    try:
        body = json.loads(event['body'])
        image_data = base64.b64decode(body['image'])
        
        event_id = str(context.aws_request_id)
        timestamp = datetime.utcnow().isoformat()
        image_key = f"events/{event_id}.jpg"

        s3.put_object(
            Bucket=BUCKET_NAME,
            Key=image_key,
            Body=image_data,
            ContentType='image/jpeg'
        )
        
        try:
            response = rekognition.search_faces_by_image(
                CollectionId=COLLECTION_ID,
                Image={'S3Object': {'Bucket': BUCKET_NAME, 'Name': image_key}},
                MaxFaces=1,
                FaceMatchThreshold=80
            )
        except rekognition.exceptions.InvalidParameterException:
            # ReKognition throws this if the YOLO crop shows a body but no visible face
            response = {'FaceMatches': []}

        status = 'Unknown'
        new_face_id = 'None'
        confidence = 0.0

        if response.get('FaceMatches'):
            matched_user = response['FaceMatches'][0]
            status = 'Recognized'
            existing_face_id = matched_user['Face']['FaceId']
            confidence = matched_user['Similarity']
            
            users_table = dynamodb.Table(TABLE_USER_NAME)
            user_info = users_table.get_item(Key={'UserID': existing_face_id})

            if 'Item' in user_info:
                display_name = user_info['Item']['Name']
                user_role = user_info['Item'].get('role', 'Undefined')

                index_response = rekognition.index_faces(
                    CollectionId=COLLECTION_ID,
                    Image={'S3Object': {'Bucket': BUCKET_NAME, 'Name': image_key}},
                    ExternalImageId=display_name.replace(' ', '_'),
                    MaxFaces=1,
                    QualityFilter='AUTO'
                )   

                if index_response['FaceRecords']:
                    new_face_id = index_response['FaceRecords'][0]['Face']['FaceId']
                    
                    if new_face_id != existing_face_id:
                        users_table.put_item(
                            Item={
                                'FaceId': new_face_id,
                                'Name': display_name,
                                'Role': user_role,
                                'CreatedAt': timestamp,
                                'S3_ProfilePicturePath': image_key
                            }
                        )
        
        events_table = dynamodb.Table(TABLE_EVENT_NAME)
        events_table.put_item(
            Item={
                'EventID': event_id,
                'CreatedAt': timestamp,
                'Status': status,
                'FaceID': new_face_id,
                'Confidence': str(confidence),
                'S3_EventImagePath': image_key
            }
        )

        if status == 'Unknown':
            presigned_url = s3.generate_presigned_url(
                'get_object',
                Params={'Bucket': BUCKET_NAME, 'Key': image_key},
                ExpiresIn=3600
            )
            #TODO: Add the ability to send the image to the user's mobile app
            sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Message=f"Smart HomeGuard: Unknown person detected at {timestamp}. Please check the image for more details. {presigned_url}",
                Subject="Security Alert: Unknown Person Detected"
            )
             
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': status,
                'face_id': new_face_id,
                'confidence': confidence
            })
        }

    except Exception as e:
        print(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'Internal Server Error': str(e)})
        }

    

        

    