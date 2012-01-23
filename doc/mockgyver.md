

#Module mockgyver#
* [Description](#description)


   
Mock functions and modules.



Copyright (c) 2011, Klas Johansson

__Behaviours:__ [`gen_server`](gen_server.md).

__Authors:__ Klas Johansson.<a name="description"></a>

##Description##




####<a name="Initiating_mock">Initiating mock</a>##




In order to use the various macros below, mocking must be
initiated using the `?MOCK` macro or `?WITH_MOCKED_SETUP`   
(recommended from eunit tests).


<h5><a name="?MOCK_syntax">?MOCK syntax</a></h5>

<pre>       ?MOCK(Expr)</pre>


where `Expr` in a single expression, like a fun.  The rest of the   
macros in this module can be used within this fun or in a function   
called by the fun.


<h5><a name="?WITH_MOCKED_SETUP_syntax">?WITH_MOCKED_SETUP syntax</a></h5>

<pre>       ?WITH_MOCKED_SETUP(SetupFun, CleanupFun),
       ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout),
       ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                          Tests),</pre>


This is an easy way of using mocks from within eunit tests and is
mock-specific version of the `?WITH_SETUP` macro.  See the docs
for the `?WITH_SETUP` macro in the `eunit_addons` project for more   
information on parameters and settings.



####<a name="Mocking_a_function">Mocking a function</a>##



<h5><a name="Introduction">Introduction</a></h5>


   
By mocking a function, its original side-effects and return value   
(or throw/exit/error) are overridden and replaced.  This can be used to:


* replace existing functions in existing modules

* add new functions to existing modules

* add new modules





BIFs (built-in functions) cannot be mocked.



The original module will be renamed (a "^" will be appended to the
original module name, i.e. `foo` will be renamed to `'foo^'`).   
A mock can then call the original function just by performing a regular   
function call.



Since WHEN is a macro, and macros don't support argument lists
(something like "Arg..."), multi-expression mocks must be
surrounded by `begin ... end` to be treated as one argument by the   
preprocessor.



A mock that was introduced using the ?WHEN macro can be forgotten,
i.e. returned to the behaviour of the original module, using the
`?FORGET_WHEN` macro.


<h5><a name="?WHEN_syntax">?WHEN syntax</a></h5>

<pre>       ?WHEN(module:function(Arg1, Arg2, ...) -> Expr),</pre>



where `Expr` is a single expression (like a term) or a series of
expressions surrounded by `begin` and `end`.


<h5><a name="?FORGET_WHEN_syntax">?FORGET_WHEN syntax</a></h5>

<pre>       ?FORGET_WHEN(module:function(_, _, ...)),</pre>



The only things of interest are the name of the module, the name   
of the function and the arity.  The arguments of the function are   
ignored and it can be a wise idea to set these to the "don't care"   
variable: underscore.


<h5><a name="Examples">Examples</a></h5>


   
Note: Apparently the Erlang/OTP team doesn't want us to redefine   
PI to 4 anymore :-), since starting at R15B, math:pi/0 is marked as   
pure which means that the compiler is allowed to replace the   
math:pi() function call by a constant: 3.14...  This means that   
even though mockgyver can mock the pi/0 function, a test case will   
never call math:pi/0 since it will be inlined.  See commit   
5adf009cb09295893e6bb01b4666a569590e0f19 (compiler: Turn calls to   
math:pi/0 into constant values) in the otp sources.

Redefine pi to 4:
<pre>       ?WHEN(math:pi() -> 4),</pre>
Implement a mock with multiple clauses:
<pre>       ?WHEN(my_module:classify_number(N) when N >= 0 -> positive;
             my_module:classify_number(_N)            -> negative),</pre>
Call original module:
<pre>       ?WHEN(math:pi() -> 'math^':pi() * 2),</pre>
Use a variable bound outside the mock:
<pre>       Answer = 42,
       ?WHEN(math:pi() -> Answer),</pre>
Redefine the mock:
<pre>       ?WHEN(math:pi() -> 4),
       4 = math:pi(),
       ?WHEN(math:pi() -> 5),
       5 = math:pi(),</pre>
Let the mock exit with an error:
<pre>       ?WHEN(math:pi() -> erlang:error(some_error)),</pre>
Make a new module:
<pre>       ?WHEN(my_math:pi() -> 4),
       ?WHEN(my_math:e() -> 3),</pre>
Put multiple clauses in a function's body:
<pre>       ?WHEN(math:pi() ->
                 begin
                     do_something1(),
                     do_something2()
                 end),</pre>
Revert the pi function to its default behaviour (return value from
the original module), any other mocks in the same module, or any
other module are left untouched:
<pre>       ?WHEN(math:pi() -> 4),
       4 = math:pi(),
       ?FORGET_WHEN(math:pi()),
       3.1415... = math:pi(),</pre>



####<a name="Validating_calls">Validating calls</a>##



<h5><a name="Introduction">Introduction</a></h5>




There are a number of ways to check that a certain function has   
been called and that works for both mocks and non-mocks.


* `?WAS_CALLED`: Check that a function was called with
certain set of parameters a chosen number of times.
The validation is done at the place of the macro, consider
this when verifying asynchronous procedures
(see also `?WAIT_CALLED`).  Return a list of argument lists,
one argument list for each call to the function.  An
argument list contains the arguments of a specific call.
Will crash with an error if the criteria isn't fulfilled.

* `?WAIT_CALLED`: Same as `?WAS_CALLED`, with a twist: waits for
the criteria to be fulfilled which can be useful for
asynchrounous procedures.

* `?GET_CALLS`: Return a list of argument lists (just like
`?WAS_CALLED` or `?WAIT_CALLED`) without checking any criteria.

* `?NUM_CALLS`: Return the number of calls to a function.

* `?FORGET_CALLS`: Forget the calls that have been logged for a
certain function.  Takes arguments and guards into account,
i.e. only the calls which match the module name, function
name and all arguments as well as any guards will be
forgotten, while the rest of the calls remain.




<h5><a name="?WAS_CALLED_syntax">?WAS_CALLED syntax</a></h5>

<pre>       ?WAS_CALLED(module:function(Arg1, Arg2, ...)),
           equivalent to ?WAS_CALLED(module:function(Arg1, Arg2, ...), once)
       ?WAS_CALLED(module:function(Arg1, Arg2, ...), Criteria),
           Criteria = once | never | {times, N} | {at_least, N} | {at_most, N}
           N = integer()
  
           Result: [CallArgs]
                   CallArgs = [CallArg]
                   CallArg = term()</pre>

<h5><a name="?WAIT_CALLED_syntax">?WAIT_CALLED syntax</a></h5>




See syntax for `?WAS_CALLED`.


<h5><a name="?GET_CALLS_syntax">?GET_CALLS syntax</a></h5>

<pre>       ?GET_CALLS(module:function(Arg1, Arg2, ...)),
  
           Result: [CallArgs]
                   CallArgs = [CallArg]
                   CallArg = term()</pre>


<h5><a name="?NUM_CALLS_syntax">?NUM_CALLS syntax</a></h5>

<pre>       ?NUM_CALLS(module:function(Arg1, Arg2, ...)),
  
           Result: integer()</pre>

<h5><a name="?FORGET_CALLS_syntax">?FORGET_CALLS syntax</a></h5>

<pre>       ?FORGET_CALLS(module:function(Arg1, Arg2, ...)),</pre>

<h5><a name="Examples">Examples</a></h5>

Check that a function has been called once (the two alternatives
are equivalent):
<pre>       ?WAS_CALLED(math:pi()),
       ?WAS_CALLED(math:pi(), once),</pre>
Check that a function has never been called:
<pre>       ?WAS_CALLED(math:pi(), never),</pre>
Check that a function has been called twice:
<pre>       ?WAS_CALLED(math:pi(), {times, 2}),</pre>
Check that a function has been called at least twice:
<pre>       ?WAS_CALLED(math:pi(), {at_least, 2}),</pre>
Check that a function has been called at most twice:
<pre>       ?WAS_CALLED(math:pi(), {at_most, 2}),</pre>
Use pattern matching to check that a function was called with
certain arguments:
<pre>       ?WAS_CALLED(lists:reverse([a, b, c])),</pre>
Pattern matching can even use bound variables:
<pre>       L = [a, b, c],
       ?WAS_CALLED(lists:reverse(L)),</pre>
Use a guard to validate the parameters in a call:
<pre>       ?WAS_CALLED(lists:reverse(L) when is_list(L)),</pre>
Retrieve the arguments in a call while verifying the number of calls:
<pre>       a = lists:nth(1, [a, b]),
       d = lists:nth(2, [c, d]),
       [[1, [a, b]], [2, [c, d]]] = ?WAS_CALLED(lists:nth(_, _), {times, 2}),</pre>
Retrieve the arguments in a call without verifying the number of calls:
<pre>       a = lists:nth(1, [a, b]),
       d = lists:nth(2, [c, d]),
       [[1, [a, b]], [2, [c, d]]] = ?GET_CALLS(lists:nth(_, _)),</pre>
Retrieve the number of calls:
<pre>       a = lists:nth(1, [a, b]),
       d = lists:nth(2, [c, d]),
       2 = ?NUM_CALLS(lists:nth(_, _)),</pre>
Forget calls to functions:
<pre>       a = lists:nth(1, [a, b, c]),
       e = lists:nth(2, [d, e, f]),
       i = lists:nth(3, [g, h, i]),
       ?WAS_CALLED(lists:nth(1, [a, b, c]), once),
       ?WAS_CALLED(lists:nth(2, [d, e, f]), once),
       ?WAS_CALLED(lists:nth(3, [g, h, i]), once),
       ?FORGET_CALLS(lists:nth(2, [d, e, f])),
       ?WAS_CALLED(lists:nth(1, [a, b, c]), once),
       ?WAS_CALLED(lists:nth(2, [d, e, f]), never),
       ?WAS_CALLED(lists:nth(3, [g, h, i]), once),
       ?FORGET_CALLS(lists:nth(_, _)),
       ?WAS_CALLED(lists:nth(1, [a, b, c]), never),
       ?WAS_CALLED(lists:nth(2, [d, e, f]), never),
       ?WAS_CALLED(lists:nth(3, [g, h, i]), never),</pre>