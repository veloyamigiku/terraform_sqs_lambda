import json

print('Loading function')

def lambda_handler(event, context):
  
  print("Received event: " + json.dumps(event, indent=2))
  body = json.loads(event['Records'][0]['body'])
  print("value1 = " + body['key1'])
  print("value2 = " + body['key2'])
  print("value3 = " + body['key3'])
  #return body['key1']  # Echo back the first key value
  raise Exception('Something went wrong')
