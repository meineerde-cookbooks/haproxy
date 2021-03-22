name "haproxy"
maintainer "Holger Just"
maintainer_email "hjust@meine-er.de"
license "Apache 2.0"
description "Installs HAProxy and provides configuration primitives"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version "0.1.4"

# Probably much more, but we still need to test that
%w{ debian ubuntu }.each do |os|
  supports os
end

depends "build-essential"
depends "perl"
depends "python"
depends "runit"
