#!/usr/bin/env bash
set -euo pipefail

# build from the lambda/ directory
rm -rf build lambda.zip

mkdir build

# install deps into build dir 
pip install -r requirements.txt -t build

cp lambda_function.py build/

(
  cd build
  zip -qr ../lambda.zip .
)

echo "lambda.zip ready"