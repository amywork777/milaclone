#!/bin/zsh
cd "${0:A:h}"
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  source "$NVM_DIR/nvm.sh"
  nvm use 24 || exit 1
fi
export HOST=127.0.0.1
export PORT=5189
npm start
