#!/bin/bash

# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

. ~/.nvm/nvm.sh

# Download and install Node.js:
nvm install 22

# Verify the Node.js version:
node -v # Should print "v22.12.0".
nvm current # Should print "v22.12.0".

# Verify npm version:
npm -v # Should print "10.9.0".

# Install pm2
npm install -g pm2
