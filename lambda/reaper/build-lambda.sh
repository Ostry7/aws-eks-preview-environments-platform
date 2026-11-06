#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

rm -rf build && mkdir build
python3 -m pip install -r requirements.txt --target build \
  --platform manylinux2014_x86_64 --implementation cp --python-version 3.14 \
  --only-binary=:all: --upgrade --quiet
cp ./*.py build/