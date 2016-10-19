Running the KillBill Integration tests with Docker
==================================================

Setup
-----

The docker installation requires docker, docker-compose and ruby
installing on the test machine.

For example on Ubuntu 16.04 run:

  sudo apt install ruby-bundler ruby-dev make gcc docker-compose language-pack-en
  sudo gpasswd -a ${USER} docker
  exec newgrp docker


Install the integration tests
-----------------------------

Clone the integration test repository and install the required gems

  git clone https://github.com/killbill/killbill-integration-tests.git
  cd killbill-integration-tests
  bundle install

Install and run the KillBill containers
---------------------------------------

Use docker-compose to start the containers using the docker-compose.yml manifest.

  docker-compose -f docker/docker-compose.yml up -d

This downloads and starts the docker containers in the background. Once the containers have started run

  docker-compose -f docker/docker-compose.yml logs

and wait for the containers to complete their startup process.


  
