#!/bin/bash
GR=`tput setaf 2`
NC=`tput sgr0`

echo "${GR}Cleaning up the environment for testing the DAPS${NC}"

# Restore server's certs from backup and cleanup testing keys directory
cd .. && rm -r omejdn-server/keys/ && mv omejdn-server/keys-backup/ omejdn-server/keys/ && \
rm -r keys/clients/*.cert && rm -r keys/clients/*.key && rm -r keys/omejdn/*.cert && \
rm -r keys/omejdn/*.key && \
echo "${GR}Restored server certs and deleted testing keys directory${NC}"

# Restore existing DAPS configuration
echo "---
- client_id: adminUI
  client_name: Omejdn Admin UI
  client_uri: http://localhost
  logo_uri: http://localhost/assets/img/fhg.jpg
  grant_types: authorization_code
  software_id: Omejdn Admin UI
  software_version: 0.0.0
  token_endpoint_auth_method: none
  redirect_uris: http://localhost
  post_logout_redirect_uris: http://localhost
  scope:
  - openid
  - omejdn:admin
  - omejdn:write
  - omejdn:read
  attributes: []" > config/clients.yml && \
mv omejdn-server/config/clients.yml.orig omejdn-server/config/clients.yml && \
mv omejdn-server/config/omejdn.yml.orig omejdn-server/config/omejdn.yml && \
mv omejdn-server/config/scope_mapping.yml.orig omejdn-server/config/scope_mapping.yml && \
echo "${GR}Restored existing DAPS configuration${NC}"

# Remove configuration file for testing
rm tests/test_config.txt && \
echo "${GR}Deleted configuration file for testing${NC}"