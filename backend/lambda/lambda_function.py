import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('cloud-resume-counter')

def lambda_handler(event, context):
    try:
        response = table.update_item(
            Key={'id': 'visitors'},
            UpdateExpression='ADD #c :val',
            ExpressionAttributeNames={'#c': 'count'},
            ExpressionAttributeValues={':val': 1},
            ReturnValues='UPDATED_NEW'
        )
        updated_count = int(response['Attributes']['count'])
        return {
            'statusCode': 200,
            'headers': {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({'count': updated_count})
        }
    except Exception as e:
        print(f"Error updating counter: {str(e)}")
        return {
            'statusCode': 500,
            'headers': { 'Access-Control-Allow-Origin': '*' },
            'body': json.dumps({'error': 'Internal Server Error'})
        }