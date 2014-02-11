# HAProxy

## Caveats

* Compile from source does not work with Chef 0.10.10 due to [CHEF-3140](http://tickets.opscode.com/browse/CHEF-3140)
* A custom OpenSSL version only works with HAProxy 1.5-dev20 or newer as we require https://github.com/haproxy/haproxy/commit/9a05945bd08be144bc6ae0551f7c2fa2b8359d12)
