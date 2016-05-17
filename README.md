# Discourse Patreon

Enable sign up and sign in with Patreon.

<img src="https://s3.amazonaws.com/patreon_public_assets/toolbox/patreon.png" width="426" height="97">

**Install Discourse Patreon!**


## Installation

Proceed with a normal [installation of a plugin](https://meta.discourse.org/t/install-a-plugin/19157?u=falco).


## After Installation

You need to fill Client ID and Client Secret on Settings -> Plugins.

To get those values you must have a [Creator account first](https://www.patreon.com/become-a-patreon-creator).

Then go to [Clients & API Keys](https://www.patreon.com/platform/documentation/clients) and fill the necessary info.

> The Redirect URIs must be http://<DISCOURSE BASE URL>/auth/patreon/callback, like https://meta.discourse.org/auth/patreon/callback

Then you use the Client ID and Client Secret to configure the plugin.

## About

This is a work in progress! Feel free to use and ask questions here, or on [Meta](meta.discourse.org).

## TODO

- Save more data that comes with the payload
- Deep integration with pledges granting group membership on Discourse

