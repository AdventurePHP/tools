# Building AdventurePHPFramework Docker images

## Prerequirements

* System with docker preinstalled

~~~bash
docker -v
Docker version 18.03.1-ce, build 9ee9f40
~~~

* Running k8s cluster (optional)

~~~bash
kubectl version
Client Version: version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.0", GitCommit:"91e7b4fd31fcd3d5f436da26c980becec37ceefe", GitTreeState:"clean", BuildDate:"2018-06-27T20:17:28Z", GoVersion:"go1.10.2", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"11", GitVersion:"v1.11.0", GitCommit:"91e7b4fd31fcd3d5f436da26c980becec37ceefe", GitTreeState:"clean", BuildDate:"2018-06-27T20:08:34Z", GoVersion:"go1.10.2", Compiler:"gc", Platform:"linux/amd64"}
~~~

## Building the APF docker image

~~~bash
cd Docker/
root@v22016124092941389:~/git/code/docker/Docker# ./build.sh
Cloning into 'code'...
remote: Counting objects: 34274, done.
remote: Total 34274 (delta 0), reused 0 (delta 0), pack-reused 34274
Receiving objects: 100% (34274/34274), 9.79 MiB | 8.52 MiB/s, done.
Resolving deltas: 100% (22659/22659), done.
Note: checking out '3.4'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by performing another checkout.

If you want to create a new branch to retain commits you create, you may
do so (now or later) by using -b with the checkout command again. Example:

  git checkout -b <new-branch-name>

HEAD is now at 4e215487 Remove old migration file.
Cloning into 'examples'...
remote: Counting objects: 4731, done.
remote: Total 4731 (delta 0), reused 0 (delta 0), pack-reused 4731
Receiving objects: 100% (4731/4731), 1.49 MiB | 2.91 MiB/s, done.
Resolving deltas: 100% (2290/2290), done.
Sending build context to Docker daemon  18.73MB
Step 1/5 : FROM php:7.2-apache
 ---> c2700d1900ac
Step 2/5 : MAINTAINER Reiner Rottmann <reiner@rottmann.it>
 ---> Using cache
 ---> c7e734afd328
Step 3/5 : ADD src/code /var/www/html/APF
 ---> 21da24dcbb29
Step 4/5 : ADD src/examples/sandbox /var/www/html
 ---> 6f3e4b83a0a6
Step 5/5 : WORKDIR /var/www/html
Removing intermediate container 2266d4be54e1
 ---> 5a42257ec6c5
Successfully built 5a42257ec6c5
Successfully tagged rottmrei/apf:latest
~~~

## Running the APF docker image locally

~~~bash
docker run -p8888:80 -it rottmrei/apf
AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
[Mon Jul 09 14:11:10.311501 2018] [mpm_prefork:notice] [pid 1] AH00163: Apache/2.4.25 (Debian) PHP/7.2.7 configured -- resuming normal operations
[Mon Jul 09 14:11:10.311632 2018] [core:notice] [pid 1] AH00094: Command line: 'apache2 -D FOREGROUND'
~~~

You may now access the APF sandbox via browser. The Docker container binds to your external ip address with port 8888. Hit CTRL+C to stop the container as it is an interactive run.

## Running the APF docker image on a k8s cluster

Please build the image before running the following commands:

~~~bash
cd Kubernetes
kubectl create -f .
~~~

This creates the following network cofiguration:

~~~
                 ┌─────────────┐
                 │  internet   │
                 └─────────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │ingress-nginx│
                 └─────────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │   apf-ing   │
                 └─────────────┘
                        │
                        ▼
                 ┌─────────────┐
                 │   apf-svc   │
                 └─────────────┘
                        │
                        ▼
                 ┌─────────────┐
       ┌─────────│   apf-rc    │─────────┐
       │         └─────────────┘         │
       │                │                │
       ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   apf-pod   │  │   apf-pod   │  │   apf-pod   │
└─────────────┘  └─────────────┘  └─────────────┘
~~~

The ingress-nginx controller routes traffic to port 80 of any nodes external ip address according to the ingress configuration.
The apf-ing ingress configuration maps inbound http requests to /apf to the apf-svc service similar to a reverse proxy. 
The apf-svc service uses round-robin to distribute requests to the 3 apf-pods that are kept healthy by the replication controller apf-rc.

