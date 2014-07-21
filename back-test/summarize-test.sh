#! /bin/bash

curl http://ds-api.internal.factual.com/inputs/places_nz/3950bf4b-99b8-4da9-9260-c59609ee6115?encoder=thrift > inputs.json
curl http://ds-api.internal.factual.com/inputs/places_nz/12a4eb61-6114-4913-a55f-cb603eddf5c7?encoder=thrift > inputs.json
curl -X PUT -H "Content-Type:application/json" "http://ds-api.internal.factual.com/summarize/places_nz" -T inputs.json

