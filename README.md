
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


Load/Perf Tests:
---------------

The integration tests also offer some support to run performance/load tests. Under 'load' there is a base class `load_base.rb` that relies on the `thread/pool` gem to schedule tasks across mutliple threads. It also offers the ability to profile the calls by using the profiling feature embedded into Kill Bill (https://github.com/killbill/killbill/wiki/Kill-Bill-Profiling).

The `payment_load.rb` test relies on `load_base.rb` and defines a set of Tasks. A task is a small scenario that should be run; it can be as simple as doing one call, or could comprise multiple operations. One should adjust the following parameters (currently hardcoded in the test) to suit its needs:
* KillBillClient.url (defaults to 'http://127.0.0.1:8080') : This is set in `load_base.rb`
* NB_ITERATIONS : number of iterations for each of the tasks with default ratio set to 1
* NB_THREADS : number of threads that should pick from the queue of tasks
* WITH_STATS : Whether test should gather statistics from server. It is advised to turn it off when running very large load tests since all the information will be kept in memory on the client side.

In addition to that, each task is given a ratio, which allows to limit the number of iterations for certain tasks. A ratio of 1 means that the task will be run NB_ITERATIONS times. A greater ratio will be used as a modulo factor to NB_ITERATIONS; for example if NB_ITERATIONS = 10, and ratio = 5, the task would run twice, one for iteration = 5 and once for iteration = 10. This is useful for instance to run a large number of payment calls against a dummy payment plugin and have in parallel a few calls hitting a third party sandbox.

Once the parameters have been set to the desired values, and after an existing instance of Kill Bill has been started, the only operation required is to run the test:

```
> bundle exec ruby killbill-integration-tests/load/payment_load.rb 
**************************    COMPLETED LOAD TESTS (nbThreads = 1)    ***************************
TASK Test (iterations = 1) err = 0
TASK AuthCapture (iterations = 1) err = 0
TASK AuthError (iterations = 0) err = 0
TASK PurchaseMultipleRefunds (iterations = 0) err = 0
TASK Credit (iterations = 0) err = 0
TASK AuthMultiCapture (iterations = 0) err = 0

Operations:
get:/1.0/kb/test/clock:                    avg = 135.00           min = 135.00           max = 135.00           tp90 = 135.00           std = 0.00            
post:/1.0/kb/accounts:                     avg = 18032.00         min = 18032.00         max = 18032.00         tp90 = 18032.00         std = 0.00            
get:/1.0/kb/accounts/uuid:                 avg = 1544.00          min = 1544.00          max = 1544.00          tp90 = 1544.00          std = 0.00            
post:/1.0/kb/accounts/uuid/paymentMethods: avg = 29391.00         min = 29391.00         max = 29391.00         tp90 = 29391.00         std = 0.00            
get:/1.0/kb/paymentMethods/uuid:           avg = 2429.00          min = 2429.00          max = 2429.00          tp90 = 2429.00          std = 0.00            
post:/1.0/kb/accounts/uuid/payments:       avg = 50477.00         min = 50477.00         max = 50477.00         tp90 = 50477.00         std = 0.00            
get:/1.0/kb/payments/uuid:                 avg = 2843.00          min = 2594.00          max = 3092.00          tp90 = 3092.00          std = 249.00          
post:/1.0/kb/payments/uuid:                avg = 85739.00         min = 85739.00         max = 85739.00         tp90 = 85739.00         std = 0.00  
```




