# The version of HAProxy to install
default['haproxy']['source']['version'] = "1.5.10"
# The checksum for the downloaded source file
# This MUST be a SHA256 sum. The MD5 sums from the HAProxy site won't suffice
default['haproxy']['source']['checksum'] = "090264c834477c290f6ad6da558731d50aede0800996742d15e870b9947fe517"
# The base-URL from which to download the source tar.gz. The full URL is
# constructed from the defined version by default. See the soyrce recipe
# for details about the exact rules.
default['haproxy']['source']['base_url'] = 'https://www.haproxy.org/download'
# You can also overriode the full URL where the tar.gz is fetched from.
# The version and the checksum MUST still be properly set.
default['haproxy']['source']['url'] = nil
# The target directory to pull the sources into and generate the compiled binary
# A subdirectory for each version is created there
default['haproxy']['source']['dir'] = "/opt/haproxy"

# Flags which should be passed to HAProxy's make
# The override the default flags
default['haproxy']['source']['flags'] = []
# Override existing flags or or add additional one here
# These flags will be reported in `haproxy -vv`
default['haproxy']['source']['define_flags'] = []
# Override existing flags or or add additional one here
# These flags will NOT be reported in `haproxy -vv`
default['haproxy']['source']['silent_define_flags'] = []

# Since HAProxy 1.5-dev12 you can add USE_OPENSSL=1 to add native SSL capability
# You then need the OpenSSL development packages installed for your platform
# (which you most probably already have).
#
# In your role, you can set this to add OpenSSL support:
#    "haproxy": {
#      "source": {
#        "flags": ["USE_OPENSSL=1"]
#      }
#    }

# If you enabled OpenSSL support, you can force a custom OpenSSL version to be
# compiled into HAProxy by setting this version.
# If this is not set, the default settings of the system are used
default['haproxy']['source']['openssl_version'] = nil
# This is the SHA256 checksum of the OpenSSL source tar.gz
default['haproxy']['source']['openssl_checksum'] = nil
# Additional flags added to ./config for OpenSSL
default['haproxy']['source']['openssl_config_flags'] = []
