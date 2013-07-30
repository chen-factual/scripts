#! /bin/bash


uuid=$1
echo uuid

curl http://ds-api.internal.factual.com/inputs/txIgmU/$uuid?encoder=thrift > inputs.json
ruby uuid-inject.rb inputs.json votes.json
curl -X PUT -T votes.json http://ds-api.internal-dev.factual.com/inputs/ivSAHE
echo "Exists:"
curl http://ds-api.internal-dev.factual.com/exists/ivSAHE/$uuid
echo ""
