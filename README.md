# Omejdn Configuration for the DAPS use case

This repository contains the necessary configuration templates to use an Omejdn instance as a DAPS as described in [IDS-G](https://github.com/International-Data-Spaces-Association/IDS-G).
This document lists the necessary steps to adapt them to your use case.

## Important Considerations

A Dynamic Attribute Provisioning System (DAPS) has the intent to assertain certain attributes to organizations and connectors.
Hence, third parties do not need to trust the latter **provided they trust the DAPS assertions**.
This is usually a matter of configuration on the verifying party's end which is not part of this document.
In general, it requires registering both the DAPS certificate and its name as a trusted identity.

**This document builds a DAPS for testing purposes only**

## Requirements

- [Omejdn Server](https://github.com/Fraunhofer-AISEC/omejdn-server)'s dependencies
- [OpenSSL](https://www.openssl.org/)
- [Docker compose](https://docs.docker.com/compose/)

This repository has submodules.
Make sure to download them using `git submodule update --init --remote`

## Minimal Configuration

The configuration consists of the following steps:

1. Adjusting configuration files
1. Registering connectors
1. Starting the server

All commands are to be run from the repository's root directory

### Configuration Files

Edit the provided `.env`.
The file includes many options you can play around with.

The default DAPS issuer identifier is `http://localhost/auth`,
which you should register with your connectors to support server metadata.

The `token_endpoint` and `jwks_uri` should be retrieved by the connector from the metadata URL
`http://localhost/.well-known/oauth-authorization-server/auth`
(replace `http`, `localhost` and `/auth` by the values you specified in `.env`).
You may use them as described in [IDS-G](https://github.com/International-Data-Spaces-Association/IDS-G).

They should default to `http://localhost/auth/token` and `http://localhost/auth/jwks.json`, respectively,
though do not rely on this in production environments as they may change with every update.
Only the metadata URL is guaranteed to stay constant.

### Registering Connectors

Connectors can be registered at any point by adding clients to the `config/clients.yml` file and placing the certificate in the right place.
To ease this process, use the provided script `scripts/register_connector.sh`

Usage:

```
$ scripts/register_connector.sh NAME SECURITY_PROFILE CERTIFICATE_FILE
```

The `SECURITY_PROFILE` and `CERTIFICATE` arguments are optional. Values for the former include:

- `idsc:BASE_SECURITY_PROFILE` (default)
- `idsc:TRUST_SECURITY_PROFILE`
- `idsc:TRUST_PLUS_SECURITY_PROFILE`

The script will automatically generate new client certificates (`keys/NAME.cert`) and keys (`keys/NAME.key`) if you do not provide a certificate manually.


### Starting the server

To start the service, execute

```
$ docker compose up
```

If you navigate to `http://localhost/`, you should be greeted by Omejdn's UI.
The UI is relatively new, so expect some bugs.

A script to quickly test your setup can be found in `scripts` (requires jq to be installed to format JSON).
It takes the name of a connector and tries to request a DAT.

```
$ scripts/test.sh NAME
```

## Hacking

There are a lot of ways one might want to extend Omejdn's functionality.
Luckily, Omejdn is quite flexible.
Below are just a few ideas.

### Adding additional attributes

For example, adding additional attributes to the DAT is as simple as listing the key in `config/scope_mapping.yml` under the right scope
and then provisioning each connector with the right attribute key and value in `config/clients.yml`.

### Adding other attribute scopes

Currently, the only defined scope is `idsc:IDS_CONNECTOR_ATTRIBUTES_ALL`,
but defining your own only requires you to specify them in `config/scope_mapping.yml` (along with the attribute keys you want to be included in that scope),
and listing the new scope under the connector's `scope` property in `config/clients.yml`.

Additionally, each such client needs an attribute with key `s` for a scope `s`, and an attribute with key `k` and value `v` for a scope `k:v`

Clients can request several scopes at once (by space-separating them in the request) and the attributes for all of them are added to the DAT.

### Adding custom functionality

Have a look at [Omejdn's Plugin API](https://github.com/Fraunhofer-AISEC/omejdn-server/blob/master/docs/Plugins/Plugins.md).
With just a bit of Ruby you can hook into the process and e.g. add anything you like to the DAT.

Here is a simple plugin example:

```ruby
def my_awesome_function(bind)
    # 1. Get the newly created DAT body
    token = bind.local_variable_get(:token)
    
    # 2. Modify it whatever you want. This example statically adds a key `key` with value `value`,
    #    but this is ruby, so you can program in here whatever you like.
    token["key"] = "value"
end

# Execute this function whenever a new DAT body has been created
PluginLoader.register('TOKEN_CREATED_ACCESS_TOKEN', :my_awesome_function)
```

To load it into Omejdn, mount it to `/opt/plugins/your_plugin_name/your_plugin_name.rb`
and add `your_plugin_name` to `omejdn-plugins.yml` as a key under `plugins`,
then restart Omejdn.

### Omejdn Config API

If you do not have Access to the DAPS and want to edit connectors (a.k.a. clients in OAuth language) and configuration remotely,
you may use Omejdn's Config API.

Using the API requires an access token with the special scope `omejdn:admin` (to be added to a client like any other scope, see above)

The Omejdn Config API is documented [here](https://github.com/Fraunhofer-AISEC/omejdn-server/blob/master/docs/).

## Testing the DAPS

 You can test the DAPS implementation with the provided Dockerfile, however, previous configuration is required. Before creating the image with the Dockerfile, the certificates and keys for 4 clients, and the DAPS signing key should be placed in the `keys` directory. A configuration file should be placed in `tests/test_config.txt`. The configuration file contains information about the clients in order to correctly request DAT tokens. An example configuration file is as follows:
 ```
iss=7D:50:61:67:B9:6E:A5:99:A9:58:30:1A:81:C7:78:8E:19:4E:20:C4:keyid:7D:50:61:67:B9:6E:A5:99:A9:58:30:1A:81:C7:78:8E:19:4E:20:C4
aud=idsc:IDS_CONNECTORS_ALL
iss_daps=http://omejdn:4567
securityProfile=idsc:BASE_SECURITY_PROFILE
referringConnector=http://test1.demo
@type=ids:DatPayload
@context=https://w3id.org/idsa/contexts/context.jsonld
scope=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL
transportCertsSha256=0c07ba5e4c305e9d1bd3d14c6e6e6b8166864e57c5b0c43b46b39d77994880b6
keyPath=../keys/test1.key
keyPath2=../keys/test2.key
iss2=30:C1:05:0A:2E:00:41:BB:6C:7B:B6:78:A1:F2:67:C7:B8:B1:02:34:keyid:30:C1:05:0A:2E:00:41:BB:6C:7B:B6:78:A1:F2:67:C7:B8:B1:02:34
url=http://localhost:4567/
iss_256=E6:60:A2:C2:C5:97:F1:76:21:DE:C4:08:26:85:E9:74:DE:0E:49:FB:keyid:E6:60:A2:C2:C5:97:F1:76:21:DE:C4:08:26:85:E9:74:DE:0E:49:FB
securityProfile_256=idsc:BASE_SECURITY_PROFILE
referringConnector_256=http://ec256.demo
scope_256=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL
transportCertsSha256_256=9f106ca3c67d4c5f997ae48fefe1107f583ff5d58a6445572944fda901916863
keyPath3=../keys/ec256.key
iss_512=2C:9E:A1:D0:CF:4B:9A:37:38:FD:32:3F:1A:49:CE:25:98:73:B3:0F:keyid:2C:9E:A1:D0:CF:4B:9A:37:38:FD:32:3F:1A:49:CE:25:98:73:B3:0F
securityProfile_512=idsc:BASE_SECURITY_PROFILE
referringConnector_512=http://ec521.demo
scope_512=idsc:IDS_CONNECTOR_ATTRIBUTES_ALL
transportCertsSha256_512=7c5b1aba8484fc8721ac75c02fddfa6b3ccd9da414cb44177a65fd96d65abf53
keyPath4=../keys/ec521.key
 ```
 Each line in the configuration file is an attribute required in that specific order and to be separated with an equal sign without spaces. The attributes refer to:
 - iss: `client_id` for the first client.
 - aud: Audience for the first client.
 - iss_daps: DAPS issuer for DAT tokens.
 - securityProfile: Expected security profile in DAT.
 - referringConnector: URI of the first client.
 - @type: Type of the DAT token.
 - @context: Context containing the IDS classes.
 - scope: List of scopes in the DAT.
 - transporteCertSha256: The public transportation key from the first client used to request a DAT token.
 - keyPath: Path to the first client's key.
 - keyPath2: Path to the second client's key.
 - iss2: `client_id` for the second client.
 - url: Address at which the DAPS server can be contacted.
 - iss_256, securityProfile_256, referingConnector_256, scope_256, transportCertSha256_256, keyPath3: These refer to the third client, which is an ES256 certificate, see above for a detailed explanation on each attribute.
 - iss_512, securityProfile_512, referingConnector_512, scope_512, transportCertSha256_512, keyPath4: These refer to the fourth client, which is an ES512 certificate, see above for a detailed explanation on each attribute. 

 Once all the required material for the testing is ready, we can start testing a DAPS instance by creating a docker image and the running a container. In order to create the image execute:
 ```
 $ docker build . -t daps-test
 ```
And then to run the container with the tests simply execute:
 ```
 $ docker run -v $PWD/tests:/tests -v $PWD/keys:/keys --name=test daps-test
 ```
