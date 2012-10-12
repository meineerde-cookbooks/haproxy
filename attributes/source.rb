# The version of HAProxy to install
default['haproxy']['source']['version'] = "1.4.22"
# The checksum for the downloaded source file
# This MUST be a SHA256 sum. The MD5 sums from the HAProxy site won't suffice
default['haproxy']['source']['checksum'] = "ba221b3eaa4d71233230b156c3000f5c2bd4dace94d9266235517fe42f917fc6"
# You can overriode the URL where the tar.gz is fetched from. The version
# and the Checksum MUST still be properly set.
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
