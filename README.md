
killbill-integration-tests
==========================

Kill Bill ruby integration test suite.

Scope
-----


The tests are written to be run against an running instance of Kill Bill with its default catalog (SpyCarBasic.xml). The tests depend on the gem killbill\_client to be installed. We are running the tests using ruby 1.9.x or 2.x.

Setup
-----

First setup correct version of ruby (using rvm, or default installed ruby version) and install the required gems:
```
# From  top of integration-tests repo (https://github.com/killbill/killbill-integration-tests)
# Note that Gemfile may point to the killbill-client gem instead of the installed version.
# (gem 'killbill-client', :path => '../killbill-client-ruby').
# (Comment or uncomment the line as appropriate)
# 
> bundle install
...
```

From there you can check the list of tests:
```
> rake -T
rake test:all              # Run tests for all
rake test:entitlement      # Run tests for entitlement
rake test:invoice          # Run tests for invoice
rake test:payment          # Run tests for payment
rake test:payment:control  # Run tests for payment:control
```

Most tests should be able to run with default kill Bill version except for the test:payment:control, which requires
the plugin https://github.com/killbill/killbill-payment-test-plugin to be installed.

Start Kill Bill locally either by following the instructions and lanching the executable war (see http://docs.kill-bill.org/userguide.html#five-minutes), or by starting the server from source repo:

```
# Make sure the database is correctly installed
# Default properties (profiles/killbill/src/main/resources/killbill-server.properties) points to 
# jdbc:mysql://127.0.0.1:3306/killbill (root/root)
# If database does not exists, you need to create it:
> echo 'create database killbill2;' | mysql -u root -proot
# Add schema (tables)
> ./bin/db-helper -a create -d killbill


# From main killbill source repo (https://github.com/killbill/killbill)
>  ./bin/start-server -s -d > /tmp/server.out 2>&1 < /dev/null &

# Tail the output and wait for the server to be fully started
> tail -f /tmp/server.out 
```


Run the tests:
-------------

By default the tests will point to the local instance of Kill Bill `KillBillClient.url = 'http://127.0.0.1:8080'`, but that can be modified -- see test\_base.rb.

From killbill-integration-tests, and after the setup is done, run some tests. for e.g:
```
> rake test:entitlement
```

All tests should pass.


About the tests:
----------------

The tests use the ruby client library to communicate through HTTP apis with Kill Bill. There are also a few special endpoints that we added for the tests; one of them is `/1.0/kb/test/clock` which is used to move the clock on Kill Bill back and forth. At the begining of each test the clock is reset to its default value (2013-08-01:T06:00:00.000Z), which is abritrary but required for writing the test assertions. During the tests, the endpoint is used to move the clock forward and generate invoices,...


It is advised to start from a clean database prior starting the tests since moving clock back and forth may trigger the system to act on some of the existing data. 

```
# Stop Kill Bill if not already done (CTRL C will work, or kill -9 PID)
# Reset the database tables:
> ./bin/db-helper -a clean
# Restart Kill Bill
> ./bin/start-server -s -d > /tmp/server.out 2>&1 < /dev/null &
```




