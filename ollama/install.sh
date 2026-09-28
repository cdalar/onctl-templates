#!/bin/bash
set -eo pipefail
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3
