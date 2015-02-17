mockgyver
=========

mockgyver is an Erlang tool which will make it easier
to write EUnit tests which need to replace or alter
(stub/mock) the behaviour of other modules.

mockgyver aims to make that process as easy as possible
with a readable and concise syntax.

mockgyver is built around two main constructs:
**?WHEN** which makes it possible to alter the
behaviour of a function and another set of macros (like
**?WAS\_CALLED**) which check that a function was called
with a chosen set of arguments.

Read more about constructs and syntax in the
documentation for the mockgyver module.

The documentation is generated using the [edown][3]
extension which generates documentation which is
immediately readable on github.  Remove the edown lines
from `rebar.config` to generate regular edoc.

A quick tutorial
----------------

Let's assume we want to make sure a fictional program
sets up an ssh connection correctly (in order to test
the part of our program which calls ssh:connect/3)
without having to start an ssh server.  Then we can use
the ?WHEN macro to replace the original ssh module and
let connect/3 return a bogus ssh\_connection\_ref():

```erlang
    ?WHEN(ssh:connect(_Host, _Port, _Opts) -> {ok, ssh_ref}),
```

Also, let's mock close/1 while we're at it to make sure
it won't crash on the bogus ssh\_ref:

```erlang
    ?WHEN(ssh:close(_ConnRef) -> ok),
```

When testing our program, we want to make sure it calls
the ssh module with the correct arguments so we'll add
these lines:

```erlang
    ?WAS_CALLED(ssh:connect({127,0,0,1}, 2022, [])),
    ?WAS_CALLED(ssh:close(ssh_ref)),
```

For all of this to work, the test needs to be
encapsulated within either the ?MOCK macro or the
?WITH\_MOCKED\_SETUP (recommended for eunit).  Assume the
test case above is within a function called
sets\_up\_and\_tears\_down\_ssh\_connection:

```erlang
    sets_up_and_tears_down_ssh_connection_test() ->
        ?MOCK(fun sets_up_and_tears_down_ssh_connection/0).
```

Or, if you prefer ?WITH\_MOCKED\_SETUP:

```erlang
    ssh_test_() ->
        ?WITH_MOCKED_SETUP(fun setup/0, fun cleanup/1).

    sets_up_and_tears_down_ssh_connection_test(_) ->
        ...
```

Sometimes a test requires a process to be started
before a test, and stopped after a test.  In that case,
the latter is better (it'll automatically export and
call all ...test/1 functions).

The final test case could look something like this:

```erlang
    -include_lib("mockgyver/include/mockgyver.hrl").

    ssh_test_() ->
        ?WITH_MOCKED_SETUP(fun setup/0, fun cleanup/1).

    setup() ->
        ok.

    cleanup(_) ->
        ok.

    sets_up_and_tears_down_ssh_connection_test(_) ->
        ?WHEN(ssh:connect(_Host, _Port, _Opts) -> {ok, ssh_ref}),
        ?WHEN(ssh:close(_ConnRef) -> ok),
        ...start the program and trigger the ssh connection to open...
        ?WAS_CALLED(ssh:connect({127,0,0,1}, 2022, [])),
        ...trigger the ssh connection to close...
        ?WAS_CALLED(ssh:close(ssh_ref)),
```

Caveats
-------

There are some pitfalls in using mockgyver that you
might want to know about.

* It's not possible to mock local functions.

  This has to do with the way mockgyver works through
  unloading and loading of modules.

* Take care when mocking modules which are used by
  other parts of the system.

  Examples include those in stdlib and kernel. A common
  pitfall is mocking io. Since mockgyver is
  potentially unloading and reloading the original
  module many times during a test suite, processes
  which are running that module may get killed as part
  of the code loading mechanism within Erlang. A common
  situation when mocking io is that eunit will stop
  printing the progress and you will wonder what has
  happened.

* NIFs cannot be mocked and mockgyver will try to
  inform you if that is the case.

* mockgyver does currently not play well with cover and
  cover will complain that a module has not been cover
  compiled. This is probably solvable.

History
-------

It all started when a friend of mine (Tomas
Abrahamsson) and I (Klas Johansson) wrote a tool we
called the stubber.  Using it looked something like this:

```erlang
    stubber:run_with_replaced_modules(
        [{math, pi, fun() -> 4 end},
         {some_module, some_function, fun(X, Y) -> ... end},
         ...],
        fun() ->
            code which should be run with replacements above
        end),
```

Time went by and we had test cases which needed a more
intricate behaviour, the stubs grew more and more
complicated and that's when I thought: it must be
possible to come up with something better and that's
when I wrote mockgyver.

Building
--------

Build mockgyver using [rebar][1].  Also,
[parse\_trans][2] (for the special syntax), [edown][3]
(for docs) and [eunit\_addons][4] (for ?WITH\_MOCKED\_SETUP)
are required, but rebar takes care of that.

```sh
$ git clone git://github.com/klajo/mockgyver.git
$ rebar get-deps
$ rebar compile
```

[1]: https://github.com/basho/rebar
[2]: https://github.com/esl/parse_trans
[3]: https://github.com/esl/edown
[4]: https://github.com/klajo/eunit_addons
