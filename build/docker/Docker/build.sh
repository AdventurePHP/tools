#!/bin/sh
branch=${1:-master}
[ -d src ] && rm -rf src
mkdir src && cd src
git clone https://github.com/AdventurePHP/code.git
cd code
git checkout $branch
cd ..
git clone https://github.com/AdventurePHP/examples.git
cd ..
docker build -t rottmrei/apf .
