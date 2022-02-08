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
error_check $? "Could not load client certificate. Are you sure you copied it into omejdn-server/keys?"

SKI="$(echo "$CERT" | grep -A1 "Subject Key Identifier" | tail -n 1 | tr -d ' ')"
AKI="$(echo "$CERT" | grep -A1 "Authority Key Identifier" | tail -n 1 | tr -d ' ')"
CLIENTID="$SKI:$AKI"
echo "Found client $CLIENTID"

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

echo $JWT

TOKEN="$(curl -Ss -Lk --post301 localhost/token --data "grant_type=client_credentials&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer&client_assertion=${JWT}&scope=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL")"
error_check $? "Omejdn did not issue a DAT. Are you sure it is running?"

echo $TOKEN
AT="$(echo $TOKEN | jq -r .access_token)"

echo "Here is the DAT Header:"
echo $AT | cut -d '.' -f1 | base64 -d 2>/dev/null | jq
echo "Here is the DAT Body:"
echo $AT | cut -d '.' -f2 | base64 -d 2>/dev/null | jq

