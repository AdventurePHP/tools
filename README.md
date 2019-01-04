[![Build Status](https://travis-ci.com/AdventurePHP/tools.svg?branch=master)](https://travis-ci.com/AdventurePHP/tools)

# Purpose

This repository contains tools for automating processes such as snapshot build, release build, and installation (Docker, Kubernetes).


# Snapshot builds

Folder **snapshot** contains the script to create snapshot releases from a certain GIT branch.
Snapshot builds of the APF are available under [GIT repository](https://adventure-php-framework.org/Page/068-GIT-repository).
Current updates can also be obtained through [packagist.org](https://packagist.org/packages/apf/apf) or directly on [github.com](https://github.com/AdventurePHP/code).


# Release builds

Folder **release** contains the script to create snapshot releases from a certain GIT branch. 
More details on how to build a release can be found in the [Wiki](https://adventure-php-framework.org/wiki/Erstellen_eines_Builds/en).
Release builds are available on the [downloads page](https://adventure-php-framework.org/Page/008-Downloads). 


# RPM

Folder **rpm** contains the script to create an RPM release. 


# Docker

Folder **docker** contains scripts to create an APF application image and to set up a web infrastructure using Kubernetes.
