#!/bin/zsh
cd "${0:A:h}"
export PATH="$HOME/.nvm/versions/node/v24.15.0/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
node sync/server.js
