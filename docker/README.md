Running the KillBill Integration tests with Docker
==================================================

Setup
-----

The docker installation requires `docker`, `docker-compose` and `ruby`
installing on the test machine.

For example on Ubuntu 16.04 run

```
$ sudo apt install ruby-bundler ruby-dev make gcc docker-compose language-pack-en
$ sudo gpasswd -a ${USER} docker
$ exec newgrp docker
```


Install the integration tests
-----------------------------

On your test machine, download the integration test repository from Github and install the required gems

```
$ git clone https://github.com/killbill/killbill-integration-tests.git
$ cd killbill-integration-tests
$ bundle install
```

Install and run the KillBill containers
---------------------------------------

Use docker-compose to start the containers using the `docker-compose.yml` manifest

```
$ docker-compose -f docker/docker-compose.yml up -d
```

The docker images will download and the containers will start in the background. Once the containers have started, view the logs

```
$ docker-compose -f docker/docker-compose.yml logs
```

and wait for the containers to complete their startup process.

Running the tests
-----------------

Either stop the log listing with Ctrl+C, or open another terminal window onto your test machine.

You can now check the list of tests
```
$ $ rake -T
[...]
rake test:all                            # Run tests for all
rake test:core                           # Run tests for core
rake test:core:entitlement               # Run tests for core:entitlement
rake test:core:invoice                   # Run tests for core:invoice
rake test:core:payment                   # Run tests for core:payment
rake test:core:tag                       # Run tests for core:tag
rake test:core:usage                     # Run tests for core:usage
rake test:multi-nodes                    # Run tests for multi-nodes
rake test:plugins:killbill-invoice-test  # Run tests for plugins:killbill-i...
rake test:plugins:payment-test           # Run tests for plugins:p...
rake test:seed                           # Run tests for seed
rake test:seed:kaui                      # Run tests for seed:kaui
```

The docker containers will run the regression test suite, which are the
core tests and the multi-nodes test. These tests are the ones included
in the `test:all` task.

To run all the regression tests

```
$ rake test:all
```

To run the core regression tests only

```
$ rake test:core
```

As well as the test tasks you can run the tests individually, eg.

```
$ rake test:all TEST=killbill-integration-tests/core/test_overdue.rb
```

Resetting the test containers
-----------------------------

The tests use the test API on the server to change the operational date of
the system, which means that each run leaves entries in the database that
can confuse subsequent runs. So it is important to reset the containers
fully between each test run. 

First stop the containers

```
$ docker-compose -f docker/docker-compose.yml stop
Stopping docker_kaui_1 ... done
Stopping docker_killbill_1 ... done
Stopping docker_killbill2_1 ... done
Stopping docker_db_1 ... done
```

and recreate them

```
$ docker-compose -f docker/docker-compose.yml up -d --force-recreate
Recreating docker_db_1
Recreating docker_killbill2_1
Recreating docker_killbill_1
Recreating docker_kaui_1
```

Check the logs again

```
$ docker-compose -f docker/docker-compose.yml logs
```

and wait for the containers to complete their startup process. You're
then ready to run another test.
