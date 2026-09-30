#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-8000}"
PYTHON="${PYTHON:-python3}"
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example. Fill in HF_TOKEN and Chroma values, then rerun."
  exit 2
fi
if [ ! -x .venv_local/bin/python ]; then
  "$PYTHON" -m venv .venv_local
fi
source .venv_local/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-local-web.txt
export SESSION_STORE_BACKEND=memory
export PYTHONPATH="$(pwd)"
exec python -m uvicorn app.web_server:app --host 127.0.0.1 --port "$PORT"
