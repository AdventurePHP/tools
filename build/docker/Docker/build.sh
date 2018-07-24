#!/bin/sh
[ -d src ] && rm -rf src
mkdir src && cd src
git clone https://github.com/AdventurePHP/code.git
cd code
git checkout 3.4
cd ..
git clone https://github.com/AdventurePHP/examples.git
cd ..
docker build -t rottmrei/apf .
