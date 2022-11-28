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

