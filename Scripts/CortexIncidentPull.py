import json
import requests
import datetime
import pprint
import collections
from collections import defaultdict
from datetime import timedelta
from json import loads


CurrentTime = datetime.datetime.utcnow()
RequestWindow = 5
StartTimeRaw = CurrentTime - timedelta(minutes=RequestWindow)
StartTimeUnix = int(StartTimeRaw.timestamp() * 1000)
uri = env:Uri
ApiTokenId = env:TokenId
apitoken = env:ApiToken
headers = { "Content-Type": "application/json",
            "Accept": "application/json",
            "Authorization": apitoken,
            "x-xdr-auth-id": str(ApiTokenId)
            }
payload = {"request_data": {}}
#paylod = {"request_data":{
#          "filters":[
#              {
#             "field": "modification_time",
#             "operator": "gte",
#              "value" : StartTimeUnix
#              }
#          ],
#              "sort":{
#                  "field": "modification_time",
#                  "keyword": "desc"
#              }
#}         
#}
# Above is our intialized variables to work with now we need to return the request themselves. 

response = requests.post(uri,json=payload,headers=headers)
RawResponse = response.json()
#pprint.pprint(RawResponse)
#print(type(RawResponse))
#pprint.pprint(RawResponse.items())
#incident_name = RawResponse['reply']['incidents']
#print(incident_name.count)
#print()
#print(json.dumps(RawResponse, indent= 5))
incidents = RawResponse['reply']['incidents']

for events in incidents:
    tags= incidents 
    print(tags)


#def test_iteration(RawResponse):
#    if isinstance(RawResponse, dict):
#        for 
#def group_Hnumber(RawResponse, tag_key):
#    results = defaultdict(list)
#if isinstance(RawResponse,dict):
#    tags = RawResponse.get(original_tags,[])
