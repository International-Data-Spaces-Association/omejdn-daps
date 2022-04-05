#!/bin/bash

cd "$(dirname "$0")" || (echo "cd failed"; exit 1)

if [ $# -ne 1 ] ; then
  echo "Invalid number of arguments: $# (expected 1)"
  echo "Usage: $0 client_name"
  exit 1
fi

error_check(){
if [ "$1" != "0" ]; then
  echo "Error: $2"
  exit 1
fi
}

CLIENTNAME="$1"
CLIENTCERT="../keys/$CLIENTNAME.cert"
CERT="$(openssl x509 -in "$CLIENTCERT" -text)"
error_check $? "Could not load client certificate."

# Load Configuration
. ../.env
echo "Trying to get a DAT for $CLIENTNAME from $OMEJDN_ISSUER"

SKI="$(echo "$CERT" | grep -A1 "Subject Key Identifier" | tail -n 1 | tr -d ' ')"
AKI="$(echo "$CERT" | grep -A1 "Authority Key Identifier" | tail -n 1 | tr -d ' ')"
CLIENTID="$SKI:$AKI"
echo "Derived connector ID: $CLIENTID"

# script mostly taken from upstream Omejdn
JWT="$(ruby /dev/stdin <<EOF
require 'openssl'
require 'jwt'
require 'json'

CLIENTNAME = '$CLIENTNAME'
CLIENTID = "$CLIENTID" 

# Only for debugging!
filename = "../keys/#{CLIENTNAME}.key"
client_rsa_key = OpenSSL::PKey::RSA.new File.read(filename)
payload = {
  'iss' => CLIENTID,
  'sub' => CLIENTID,
  'exp' => Time.new.to_i + 3600,
  'nbf' => Time.new.to_i,
  'iat' => Time.new.to_i,
  'aud' => 'idsc:IDS_CONNECTORS_ALL'
}
token = JWT.encode payload, client_rsa_key, 'RS256'
puts token
EOF
)"
error_check $? "Could not create Test JWT"

# Acquire the metadata document (IMPORTANT: This is ignoring the server's certificate validity. DO NOT USE THIS IN PRODUCTION!)
[ "$OMEJDN_PATH" == "/" ] && OMEJDN_PATH="" # Erase root path
METADATA_URL="$OMEJDN_PROTOCOL://$OMEJDN_DOMAIN/.well-known/oauth-authorization-server$OMEJDN_PATH"
echo "Aquiring the server's metadata document from $METADATA_URL"
METADATA="$(curl -Ss -Lk --post301 "$METADATA_URL")"
error_check $? "Could not aquire the server's metadata. Are you sure Omejdn is running?"

# Extract the token endpoint
TOKEN_ENDPOINT="$(echo "$METADATA" | jq -r .token_endpoint)"
echo "The token endpoint is $TOKEN_ENDPOINT"

# Request a DAT (IMPORTANT: This is ignoring the server's certificate validity. DO NOT USE THIS IN PRODUCTION!)
echo "Requesting a DAT from the above token endpoint"
TOKEN="$(curl -Ss -Lk --post301 $TOKEN_ENDPOINT --data "grant_type=client_credentials&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=${JWT}&scope=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL")"
error_check $? "Omejdn did not issue a DAT. Are you sure it is running?"

# Error checking
ERROR="$(echo $TOKEN | jq -r .error)"
ERROR_DESC="$(echo $TOKEN | jq -r .error_description)"
if [ "$ERROR" != "null" ]; then
  error_check 1 "Received Error Code $ERROR: $ERROR_DESC"
fi

# Extract and decode the DAT (IMPORTANT: This is not checking any signatures. DO NOT USE THIS IN PRODUCTION!)
AT="$(echo $TOKEN | jq -r .access_token)"
echo "Here is the DAT Header:"
echo $AT | cut -d '.' -f1 | base64 -d 2>/dev/null | jq
echo "Here is the DAT Body:"
echo $AT | cut -d '.' -f2 | base64 -d 2>/dev/null | jq

