%%%===================================================================
%%% Copyright (c) 2011, Klas Johansson
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are
%%% met:
%%%
%%%     * Redistributions of source code must retain the above copyright
%%%       notice, this list of conditions and the following disclaimer.
%%%
%%%     * Redistributions in binary form must reproduce the above copyright
%%%       notice, this list of conditions and the following disclaimer in
%%%       the documentation and/or other materials provided with the
%%%       distribution.
%%%
%%%     * Neither the name of the copyright holder nor the names of its
%%%       contributors may be used to endorse or promote products derived
%%%       from this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%%% IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%%% TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%% HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%% TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%% PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%% LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%%%===================================================================

%%%-------------------------------------------------------------------
%%% @author Klas Johansson
%%% @copyright 2011, Klas Johansson
%%% @doc
%%% Mock functions and modules
%%%
%%% === Initiating mock ===
%%%
%%% In order to use the various macros below, mocking must be
%%% initiated using the `?MOCK' macro or `?WITH_MOCKED_SETUP'
%%% (recommended from eunit tests).
%%%
%%% ==== ?MOCK syntax ====
%%% <pre lang="erlang">
%%%     ?MOCK(Expr)
%%% </pre>
%%% where `Expr' in a single expression, like a fun.  The rest of the
%%% macros in this module can be used within this fun or in a function
%%% called by the fun.
%%%
%%% ==== ?WITH_MOCKED_SETUP syntax ====
%%% <pre lang="erlang">
%%%     ?WITH_MOCKED_SETUP(SetupFun, CleanupFun),
%%%     ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout),
%%%     ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
%%%                        Tests),
%%% </pre>
%%% This is an easy way of using mocks from within eunit tests and is
%%% mock-specific version of the `?WITH_SETUP' macro.  See the docs
%%% for the `?WITH_SETUP' macro in the `eunit_addons' project for more
%%% information on parameters and settings.
%%%
%%% === Mocking a function ===
%%%
%%% ==== Introduction ====
%%% By mocking a function, its original side-effects and return value
%%% (or throw/exit/error) are overridden and replaced.  This can be used to:
%%%
%%% <ul>
%%%   <li>replace existing functions in existing modules</li>
%%%   <li>add new functions to existing modules</li>
%%%   <li>add new modules</li>
%%% </ul>
%%%
%%% BIFs (built-in functions) cannot be mocked.
%%%
%%% The original module will be renamed (a "^" will be appended to the
%%% original module name, i.e. ``foo'' will be renamed to `` 'foo^' '').
%%% A mock can then call the original function just by performing a regular
%%% function call.
%%%
%%% Since WHEN is a macro, and macros don't support argument lists
%%% (something like "Arg..."), multi-expression mocks must be
%%% surrounded by `begin ... end' to be treated as one argument by the
%%% preprocessor.
%%%
%%% A mock that was introduced using the ?WHEN macro can be forgotten,
%%% i.e. returned to the behaviour of the original module, using the
%%% `?FORGET_WHEN' macro.
%%%
%%% ==== ?WHEN syntax ====
%%% <pre lang="erlang">
%%%     ?WHEN(module:function(Arg1, Arg2, ...) -> Expr),
%%% </pre>
%%%
%%% where `Expr' is a single expression (like a term) or a series of
%%% expressions surrounded by `begin' and `end'.
%%%
%%% ==== ?FORGET_WHEN syntax ====
%%% <pre lang="erlang">
%%%     ?FORGET_WHEN(module:function(_, _, ...)),
%%% </pre>
%%%
%%% The only things of interest are the name of the module, the name
%%% of the function and the arity.  The arguments of the function are
%%% ignored and it can be a wise idea to set these to the "don't care"
%%% variable: underscore.
%%%
%%% ==== Examples ====
%%% Note: Apparently the Erlang/OTP team doesn't want us to redefine
%%% PI to 4 anymore :-), since starting at R15B, math:pi/0 is marked as
%%% pure which means that the compiler is allowed to replace the
%%% math:pi() function call by a constant: 3.14...  This means that
%%% even though mockgyver can mock the pi/0 function, a test case will
%%% never call math:pi/0 since it will be inlined.  See commit
%%% 5adf009cb09295893e6bb01b4666a569590e0f19 (compiler: Turn calls to
%%% math:pi/0 into constant values) in the otp sources.
%%%
%%% Redefine pi to 4:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() -> 4),
%%% </pre>
%%% Implement a mock with multiple clauses:
%%% <pre lang="erlang">
%%%     ?WHEN(my_module:classify_number(N) when N >= 0 -> positive;
%%%           my_module:classify_number(_N)            -> negative),
%%% </pre>
%%% Call original module:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() -> 'math^':pi() * 2),
%%% </pre>
%%% Use a variable bound outside the mock:
%%% <pre lang="erlang">
%%%     Answer = 42,
%%%     ?WHEN(math:pi() -> Answer),
%%% </pre>
%%% Redefine the mock:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() -> 4),
%%%     4 = math:pi(),
%%%     ?WHEN(math:pi() -> 5),
%%%     5 = math:pi(),
%%% </pre>
%%% Let the mock exit with an error:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() -> erlang:error(some_error)),
%%% </pre>
%%% Make a new module:
%%% <pre lang="erlang">
%%%     ?WHEN(my_math:pi() -> 4),
%%%     ?WHEN(my_math:e() -> 3),
%%% </pre>
%%% Put multiple clauses in a function's body:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() ->
%%%               begin
%%%                   do_something1(),
%%%                   do_something2()
%%%               end),
%%% </pre>
%%% Revert the pi function to its default behaviour (return value from
%%% the original module), any other mocks in the same module, or any
%%% other module are left untouched:
%%% <pre lang="erlang">
%%%     ?WHEN(math:pi() -> 4),
%%%     4 = math:pi(),
%%%     ?FORGET_WHEN(math:pi()),
%%%     3.1415... = math:pi(),
%%% </pre>
%%%
%%% === Validating calls ===
%%%
%%% ==== Introduction ====
%%%
%%% There are a number of ways to check that a certain function has
%%% been called and that works for both mocks and non-mocks.
%%%
%%% <ul>
%%%   <li>`?WAS_CALLED': Check that a function was called with
%%%       certain set of parameters a chosen number of times.
%%%       The validation is done at the place of the macro, consider
%%%       this when verifying asynchronous procedures
%%%       (see also `?WAIT_CALLED').  Return a list of argument lists,
%%%       one argument list for each call to the function.  An
%%%       argument list contains the arguments of a specific call.
%%%       Will crash with an error if the criteria isn't fulfilled.</li>
%%%   <li>`?WAIT_CALLED': Same as `?WAS_CALLED', with a twist: waits for
%%%       the criteria to be fulfilled which can be useful for
%%%       asynchrounous procedures.</li>
%%%   <li>`?GET_CALLS': Return a list of argument lists (just like
%%%       `?WAS_CALLED' or `?WAIT_CALLED') without checking any criteria.</li>
%%%   <li>`?NUM_CALLS': Return the number of calls to a function.</li>
%%%   <li>`?FORGET_CALLS': Forget the calls that have been logged.
%%%        This exists in two versions:
%%%        <ul>
%%%          <li>One which forgets calls to a certain function.
%%%              Takes arguments and guards into account, i.e. only
%%%              the calls which match the module name, function
%%%              name and all arguments as well as any guards will
%%%              be forgotten, while the rest of the calls remain.</li>
%%%          <li>One which forgets all calls to any function.</li>
%%%        </ul>
%%%   </li>
%%% </ul>
%%%
%%% ==== ?WAS_CALLED syntax ====
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(module:function(Arg1, Arg2, ...)),
%%%         equivalent to ?WAS_CALLED(module:function(Arg1, Arg2, ...), once)
%%%     ?WAS_CALLED(module:function(Arg1, Arg2, ...), Criteria),
%%%         Criteria = once | never | {times, N} | {at_least, N} | {at_most, N}
%%%         N = integer()
%%%
%%%         Result: [CallArgs]
%%%                 CallArgs = [CallArg]
%%%                 CallArg = term()
%%%
%%% </pre>
%%% ==== ?WAIT_CALLED syntax ====
%%%
%%% See syntax for `?WAS_CALLED'.
%%%
%%% ==== ?GET_CALLS syntax ====
%%% <pre lang="erlang">
%%%     ?GET_CALLS(module:function(Arg1, Arg2, ...)),
%%%
%%%         Result: [CallArgs]
%%%                 CallArgs = [CallArg]
%%%                 CallArg = term()
%%% </pre>
%%%
%%% ==== ?NUM_CALLS syntax ====
%%% <pre lang="erlang">
%%%     ?NUM_CALLS(module:function(Arg1, Arg2, ...)),
%%%
%%%         Result: integer()
%%% </pre>
%%% ==== ?FORGET_CALLS syntax ====
%%% <pre lang="erlang">
%%%     ?FORGET_CALLS(module:function(Arg1, Arg2, ...)),
%%%     ?FORGET_CALLS(),
%%% </pre>
%%% ==== Examples ====
%%% Check that a function has been called once (the two alternatives
%%% are equivalent):
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(math:pi()),
%%%     ?WAS_CALLED(math:pi(), once),
%%% </pre>
%%% Check that a function has never been called:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(math:pi(), never),
%%% </pre>
%%% Check that a function has been called twice:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(math:pi(), {times, 2}),
%%% </pre>
%%% Check that a function has been called at least twice:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(math:pi(), {at_least, 2}),
%%% </pre>
%%% Check that a function has been called at most twice:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(math:pi(), {at_most, 2}),
%%% </pre>
%%% Use pattern matching to check that a function was called with
%%% certain arguments:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(lists:reverse([a, b, c])),
%%% </pre>
%%% Pattern matching can even use bound variables:
%%% <pre lang="erlang">
%%%     L = [a, b, c],
%%%     ?WAS_CALLED(lists:reverse(L)),
%%% </pre>
%%% Use a guard to validate the parameters in a call:
%%% <pre lang="erlang">
%%%     ?WAS_CALLED(lists:reverse(L) when is_list(L)),
%%% </pre>
%%% Retrieve the arguments in a call while verifying the number of calls:
%%% <pre lang="erlang">
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     [[1, [a, b]], [2, [c, d]]] = ?WAS_CALLED(lists:nth(_, _), {times, 2}),
%%% </pre>
%%% Retrieve the arguments in a call without verifying the number of calls:
%%% <pre lang="erlang">
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     [[1, [a, b]], [2, [c, d]]] = ?GET_CALLS(lists:nth(_, _)),
%%% </pre>
%%% Retrieve the number of calls:
%%% <pre lang="erlang">
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     2 = ?NUM_CALLS(lists:nth(_, _)),
%%% </pre>
%%% Forget calls to functions:
%%% <pre lang="erlang">
%%%     a = lists:nth(1, [a, b, c]),
%%%     e = lists:nth(2, [d, e, f]),
%%%     i = lists:nth(3, [g, h, i]),
%%%     ?WAS_CALLED(lists:nth(1, [a, b, c]), once),
%%%     ?WAS_CALLED(lists:nth(2, [d, e, f]), once),
%%%     ?WAS_CALLED(lists:nth(3, [g, h, i]), once),
%%%     ?FORGET_CALLS(lists:nth(2, [d, e, f])),
%%%     ?WAS_CALLED(lists:nth(1, [a, b, c]), once),
%%%     ?WAS_CALLED(lists:nth(2, [d, e, f]), never),
%%%     ?WAS_CALLED(lists:nth(3, [g, h, i]), once),
%%%     ?FORGET_CALLS(lists:nth(_, _)),
%%%     ?WAS_CALLED(lists:nth(1, [a, b, c]), never),
%%%     ?WAS_CALLED(lists:nth(2, [d, e, f]), never),
%%%     ?WAS_CALLED(lists:nth(3, [g, h, i]), never),
%%% </pre>
%%% Forget calls to all functions:
%%% <pre lang="erlang">
%%%     a = lists:nth(1, [a, b, c]),
%%%     e = lists:nth(2, [d, e, f]),
%%%     i = lists:nth(3, [g, h, i]),
%%%     ?WAS_CALLED(lists:nth(1, [a, b, c]), once),
%%%     ?WAS_CALLED(lists:nth(2, [d, e, f]), once),
%%%     ?WAS_CALLED(lists:nth(3, [g, h, i]), once),
%%%     ?FORGET_CALLS(),
%%%     ?WAS_CALLED(lists:nth(1, [a, b, c]), never),
%%%     ?WAS_CALLED(lists:nth(2, [d, e, f]), never),
%%%     ?WAS_CALLED(lists:nth(3, [g, h, i]), never),
%%% </pre>
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver).

-behaviour(gen_fsm).

%% This transform makes it easier for this module to generate code.
%% Depends on a 3pp library (http://github.com/esl/parse_trans).
-compile({parse_transform, parse_trans_codegen}).

%% API
-export([exec/3]).

-export([start_link/0]).
-export([stop/0]).

-export([reg_call_and_get_action/1, get_action/1, set_action/1, set_action/2]).
-export([verify/2, verify/3]).
-export([forget_all_calls/0]).

%% For test
-export([check_criteria/2]).

%% gen_fsm callbacks
-export([init/1, no_session/2, no_session/3, session/2, session/3,
         handle_event/3, handle_sync_event/4, handle_info/3,
         terminate/3, code_change/4]).

-define(SERVER, ?MODULE).
-define(CACHE_TAB, list_to_atom(?MODULE_STRING ++ "_mocking_module_cache")).

-define(beam_num_bytes_alignment, 4). %% according to spec below

-define(cand_resem_threshold, 5). %% threshold for similarity (0 = identical)

-record(state, {actions=[], calls, session_mref, session_waiters=queue:new(),
                call_waiters=[], mock_mfas=[], watch_mfas=[]}).
-record(call, {m, f, a}).
-record(action, {mfa, func}).
-record(call_waiter, {from, mfa, crit, loc}).

%-record(trace, {msg}).
-record('DOWN', {mref, type, obj, info}).

%%%===================================================================
%%% API
%%%===================================================================

%% @private
exec(MockMFAs, WatchMFAs, Fun) ->
    ok = ensure_application_started(),
    try
        case start_session(MockMFAs, WatchMFAs) of
            ok                 -> Fun();
            {error, _} = Error -> erlang:error(Error)
        end
    after
        end_session()
    end.

%% @private
reg_call_and_get_action(MFA) ->
    chk(sync_send_event({reg_call_and_get_action, MFA})).

%% @private
get_action(MFA) ->
    chk(sync_send_event({get_action, MFA})).

%% @private
set_action(MFA) ->
    set_action(MFA, _Opts=[]).

%% @private
set_action(MFA, Opts) ->
    chk(sync_send_event({set_action, MFA, Opts})).

%% @private
start_link() ->
    gen_fsm:start_link({local, ?SERVER}, ?MODULE, {}, []).

%% @private
stop() ->
    sync_send_all_state_event(stop).

ensure_application_started() ->
    case application:start(?MODULE) of
        ok                            -> ok;
        {error, {already_started, _}} -> ok;
        {error, _} = Error            -> Error
    end.

start_session(MockMFAs, WatchMFAs) ->
    sync_send_event({start_session, MockMFAs, WatchMFAs, self()}).

end_session() ->
    sync_send_event(end_session).

%% @private
%% once | {at_least, N} | {at_most, N} | {times, N} | never
verify({M, F, A}, Criteria) ->
    verify({M, F, A}, Criteria, _Opts=[]).

%% @private
verify({M, F, A}, Criteria, Opts) ->
    wait_until_trace_delivered(),
    chk(sync_send_event({verify, {M, F, A}, Criteria, Opts})).

%% @private
forget_all_calls() ->
    chk(sync_send_event(forget_all_calls)).

%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init({}) ->
    create_mocking_mod_cache(),
    {ok, no_session, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec no_session(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
no_session(_Event, State) ->
    {next_state, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @spec no_session(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
no_session({start_session, MockMFAs, WatchMFAs, Pid}, _From, State0) ->
    {Reply, State} = i_start_session(MockMFAs, WatchMFAs, Pid, State0),
    {reply, Reply, session, State};
no_session(_Other, _From, State) ->
    {reply, {error, mocking_not_started}, no_session, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same
%% name as the current state name StateName is called to handle
%% the event. It is also called if a timeout occurs.
%%
%% @spec session(Event, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
session(_Event, State) ->
    {next_state, state_name, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/[2,3], the instance of this function with
%% the same name as the current state name StateName is called to
%% handle the event.
%%
%% @spec session(Event, From, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
session({start_session, MockMFAs, WatchMFAs, Pid}, From, State0) ->
    State = enqueue_session({From, MockMFAs, WatchMFAs, Pid}, State0),
    {next_state, session, State};
session(end_session, _From, State0) ->
    {NextStateName, State1} = i_end_session_and_possibly_dequeue(State0),
    {reply, ok, NextStateName, State1};
session({reg_call_and_get_action, MFA}, _From, State0) ->
    State = register_call(MFA, State0),
    ActionFun = i_get_action(MFA, State),
    {reply, {ok, ActionFun}, session, State};
session({get_action, MFA}, _From, State) ->
    ActionFun = i_get_action(MFA, State),
    {reply, {ok, ActionFun}, session, State};
session({set_action, MFA, Opts}, _From, State0) ->
    {Reply, State} = i_set_action(MFA, Opts, State0),
    {reply, Reply, session, State};
session({verify, MFA, {was_called, Criteria}, Opts}, _From, State) ->
    Reply = get_and_check_matches(MFA, Criteria, State),
    {reply, possibly_add_location(Reply, Opts), session, State};
session({verify, MFA, {wait_called, Criteria}, Opts}, From, State) ->
    case get_and_check_matches(MFA, Criteria, State) of
        {ok, _} = Reply ->
            {reply, Reply, session, State};
        {error, {fewer_calls_than_expected, _, _}} ->
            %% It only makes sense to enqueue waiters if their
            %% criteria is not yet fulfilled - at least there's a
            %% chance it might actually happen.
            Waiters = State#state.call_waiters,
            Waiter  = #call_waiter{from=From, mfa=MFA, crit=Criteria,
                                   loc=proplists:get_value(location, Opts)},
            {next_state, session, State#state{call_waiters = [Waiter|Waiters]}};
        {error, _} = Error ->
            %% Fail directly if the waiter's criteria can never be
            %% fulfilled, if the criteria syntax was bad, etc.
            {reply, possibly_add_location(Error, Opts), session, State}
    end;
session({verify, MFA, num_calls, _Opts}, _From, State) ->
    Matches = get_matches(MFA, State),
    {reply, {ok, length(Matches)}, session, State};
session({verify, MFA, get_calls, _Opts}, _From, State) ->
    Matches = get_matches(MFA, State),
    {reply, {ok, Matches}, session, State};
session({verify, MFA, forget_when, _Opts}, _From, State0) ->
    State = i_forget_action(MFA, State0),
    {reply, ok, session, State};
session({verify, MFA, forget_calls, _Opts}, _From, State0) ->
    State = remove_matching_calls(MFA, State0),
    {reply, ok, session, State};
session(forget_all_calls, _From, State) ->
    {reply, ok, session, State#state{calls=[]}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(stop, _From, _StateName, State) ->
    {stop, normal, ok, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it receives any
%% message other than a synchronous or asynchronous event
%% (or a system message).
%%
%% @spec handle_info(Info,StateName,State)->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_info(#'DOWN'{mref=MRef}, _StateName, #state{session_mref=MRef,
                                                  call_waiters=Waiters,
                                                  calls=Calls}=State0) ->
    %% The test died before it got a chance to clean up after itself.
    %% Check whether there are any pending waiters.  If so, just print
    %% the calls we've logged so far.  Hopefully that helps in
    %% debugging.  This is probably the best we can accomplish -- being
    %% able to fail the eunit test would be nice.  Another day perhaps.
    possibly_print_call_waiters(Waiters, Calls),
    {NextStateName, State1} = i_end_session_and_possibly_dequeue(State0),
    {next_state, NextStateName, State1};
handle_info({trace, _, call, MFA}, StateName, State0) ->
    State = register_call(MFA, State0),
    {next_state, StateName, State};
handle_info(Info, StateName, State) ->
    io:format(user, "~p got message: ~p~n", [?MODULE, Info]),
    {next_state, StateName, State}.

is_within_session(#state{session_mref=MRef}) -> MRef =/= undefined.

enqueue_session(Session, #state{session_waiters=Waiters}=State) ->
    State#state{session_waiters=queue:in(Session, Waiters)}.

possibly_dequeue_session(#state{session_waiters=Waiters0}=State0) ->
    case queue:out(Waiters0) of
        {{value, {From, MockMFAs, WatchMFAs, Pid}}, Waiters} ->
            {Reply, State} = i_start_session(MockMFAs, WatchMFAs, Pid, State0),
            gen_server:reply(From, Reply),
            State#state{session_waiters=Waiters};
        {empty, _} ->
            State0
    end.

possibly_print_call_waiters([], _Calls) ->
    ok;
possibly_print_call_waiters(Waiters, Calls) ->
    io:format(user,
              "Test died while waiting for a call.~n~n"
              "~s~n",
              [[fmt_waiter_calls(Waiter, Calls) || Waiter <- Waiters]]).

fmt_waiter_calls(#call_waiter{mfa={WaitM,WaitF,WaitA0}, loc={File,Line}}=Waiter,
                 Calls) ->
    {arity, WaitA} = erlang:fun_info(WaitA0, arity),
    CandMFAs = get_sorted_candidate_mfas(Waiter),
    CallMFAs = get_sorted_calls_similar_to_waiter(Waiter, Calls),
    lists:flatten(
      [f("~s:~p:~n    Waiter: ~p:~p/~p~n~n", [File, Line, WaitM, WaitF, WaitA]),
       case CandMFAs of
           [] ->
               f("    Unfortunately there are no similar functions~n", []);
           [{WaitM, WaitF, WaitA}] ->
               "";
           _ ->
               f("    Did you intend to verify one of these functions?~n"
                 "~s~n",
                 [fmt_candidate_mfas(CandMFAs, _Indent=8)])
       end,
       case CallMFAs of
           [] -> f("    Unfortunately there are no registered calls~n", []);
           _  -> f("    Registered calls in order of decreasing similarity:~n"
                   "~s~n",
                   [fmt_calls(CallMFAs, _Indent=8)])
       end,
       f("~n", [])]).

fmt_calls(Calls, Indent) ->
    string:join([fmt_call(Call, Indent) || Call <- Calls], ",\n").

fmt_call(#call{m=M, f=F, a=As}, Indent) ->
    %% This is a crude way of pretty printing the MFA, in a way that
    %% both literals and non-literals in As are printed. Example:
    %%
    %% Input:
    %%
    %%     #call{m = mockgyver_dummy,
    %%           f = return_arg,
    %%           a = [fun() -> ok end, 1, "abc", #{f=>100}, lists:seq(1,100)]
    %%
    %% Output:
    %%
    %%         mockgyver_dummy:return_arg([#Fun<mockgyver_tests.0.124618725>,1,"abc",
    %%                                     #{f => 100},
    %%                                     [1,2,3,4,5,6,7,8,9,10,11,12,13|...]])
    %% ^^^^^^^^--- this is the indent
    IndentStr = string:chars($\s, Indent),
    %% This is all the text up to, but not including, the first "("
    Preamble = io_lib:format("~s~p:~p", [IndentStr, M, F]),
    PreambleLen = string:length(Preamble),
    %% This is all the arguments pretty-printed. Since they're in a
    %% list and that will also be included in the output, strip the
    %% leading "[" and trailing "]" from the output.
    FmtStr = f("~~~p.~pP", [_LineLength=80, _ArgIdent=PreambleLen + 1]),
    AsStr0 = f(FmtStr, [As, _Depth=20]),
    AsStr = string:sub_string(AsStr0, 2, string:length(AsStr0)-1),
    %% Crudeness is done
    f("~s(~s)", [Preamble, AsStr]).

get_sorted_calls_similar_to_waiter(#call_waiter{}=Waiter, Calls) ->
    ResemCalls0 = calc_resemblance_for_calls(Waiter, Calls),
    ResemCalls1 = [ResemCall || {Resem, #call{}}=ResemCall <- ResemCalls0,
                                Resem =< ?cand_resem_threshold],
    ResemCalls = lists:sort(fun({Resem1, #call{}}, {Resem2, #call{}}) ->
                                    Resem1 =< Resem2
                            end,
                            ResemCalls1),
    [Call || {_Resem, #call{}=Call} <- ResemCalls].

calc_resemblance_for_calls(#call_waiter{mfa={WaitM,WaitF,WaitA0}}, Calls) ->
    {arity, WaitA} = erlang:fun_info(WaitA0, arity),
    [{calc_mfa_resemblance({WaitM,WaitF,WaitA}, {CallM,CallF,length(CallA)}),
      Call}||
         #call{m=CallM, f=CallF, a=CallA}=Call <- Calls].

fmt_candidate_mfas(CandMFAs, Indent) ->
    [string:chars($\s, Indent) ++ f("~p:~p/~p~n", [CandM, CandF, CandA]) ||
        {CandM, CandF, CandA} <- CandMFAs].

get_sorted_candidate_mfas(#call_waiter{mfa={WaitM,WaitF,WaitA0}}=Waiter) ->
    {arity, WaitA} = erlang:fun_info(WaitA0, arity),
    WaitMFA = {WaitM, WaitF, WaitA},
    CandMFAs = lists:sort(fun({Resem1, _CandMFA1}, {Resem2, _CandMFA2}) ->
                                  Resem1 =< Resem2
                          end,
                          get_candidate_mfas_aux(get_candidate_modules(Waiter),
                                                 WaitMFA)),
    [CandMFA || {_Resem, CandMFA} <- CandMFAs].

get_candidate_mfas_aux([CandM | CandMs], WaitMFA) ->
    get_candidate_mfas_by_module(CandM, WaitMFA)
        ++ get_candidate_mfas_aux(CandMs, WaitMFA);
get_candidate_mfas_aux([], _WaitMFA) ->
    [].

get_candidate_mfas_by_module(CandM, WaitMFA) ->
    CandFAs = CandM:module_info(exports),
    lists:foldl(
      fun(CandMFA, CandMFAs) ->
              %% Only include similar MFAs
              case calc_mfa_resemblance(WaitMFA, CandMFA) of
                  Resem when Resem =< ?cand_resem_threshold ->
                      [{Resem, CandMFA} | CandMFAs];
                  _Resem ->
                      CandMFAs
              end
      end,
      [],
      [{CandM, CandF, CandA} || {CandF, CandA} <- CandFAs]).

%% Return a list of all loaded modules which are similar
get_candidate_modules(#call_waiter{mfa={WaitM, _WaitF, _WaitA}}) ->
    [CandM || {CandM, _Loaded} <- code:all_loaded(),
              calc_atom_resemblance(WaitM, CandM) =< ?cand_resem_threshold,
              not is_mocked_module(CandM)].

is_mocked_module(M) ->
    lists:suffix("^", atom_to_list(M)).

%% Calculate a positive integer which corresponds to the similarity
%% between two MFAs.  Returns 0 when they are equal.
calc_mfa_resemblance({M1, F1, A1}, {M2, F2, A2}) ->
    calc_atom_resemblance(M1, M2) + calc_atom_resemblance(F1, F2) + abs(A1-A2).

calc_atom_resemblance(A1, A2) ->
    calc_levenshtein_dist(atom_to_list(A1),
                          atom_to_list(A2)).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, State) ->
    i_end_session(State), % ensure mock modules are unloaded when terminating
    destroy_mocking_mod_cache(),
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

sync_send_event(Msg) ->
    gen_fsm:sync_send_event(?SERVER, Msg, infinity).

sync_send_all_state_event(Msg) ->
    gen_fsm:sync_send_all_state_event(?SERVER, Msg, infinity).

i_start_session(MockMFAs, WatchMFAs, Pid, State0) ->
    State = State0#state{mock_mfas=MockMFAs, watch_mfas=WatchMFAs},
    MockMods = get_unique_mods_by_mfas(MockMFAs),
    mock_and_load_mods(MockMFAs),
    possibly_shutdown_old_tracer(),
    erlang:trace(all, true, [call, {tracer, self()}]),
    %% We mustn't trace non-mocked modules, since we'll register
    %% calls for those as part of reg_call_and_get_action.  If we
    %% did, we'd get double the amount of calls.
    TraceMFAs = get_trace_mfas(WatchMFAs, MockMods),
    case setup_trace_on_all_mfas(TraceMFAs) of
        ok ->
            MRef = erlang:monitor(process, Pid),
            {ok, State#state{calls=[], session_mref=MRef}};
        {error, _}=Error ->
            {Error, i_end_session(State)}
    end.

possibly_shutdown_old_tracer() ->
    %% The problem here is that a process may only be traced by one
    %% and only one other process.  We need the traces to record what
    %% happens for the validation afterwards.  One could perhaps
    %% design a complicated trace relay, but at least for the time
    %% being we stop the current tracer (if any) and add ourselves as
    %% the sole tracer.
    case get_orig_tracer_info() of
        {_Tracer, Flags} ->
            %% One could warn the user about this happening, but
            %% what's a good way of doing that?
            %%
            %% * error_logger:info_msg/warning_msg is always shown
            %%   ==> clutters eunit results in the shell and there's
            %%       no way of turning that off
            %%
            %% * io:format(Format, Args) is only shown if an eunit
            %%   test case fails (I think), increasing the verbosity
            %%   doesn't help
            %%   ==> bad, since one would like to see the warning at
            %%       least in verbose mode
            %%
            %% * io:format(user, Format, Args) is always shown
            %%   ==> see error_logger bullet above
            %%
            %% Just silently steal the trace.
            erlang:trace(all, false, Flags);
        undefined ->
            ok
    end.

get_orig_tracer_info() ->
    case erlang:trace_info(new, tracer) of
        {tracer, []} ->
            undefined;
        {tracer, Tracer} ->
            {flags, Flags} = erlang:trace_info(new, flags),
            {Tracer, Flags}
    end.

get_trace_mfas(WatchMFAs, MockMods) ->
    [{M,F,A} || {M,F,A} <- WatchMFAs, not lists:member(M, MockMods)].

setup_trace_on_all_mfas(MFAs) ->
    lists:foldl(fun({M,_F,_A} = MFA, ok) ->
                        %% Ensure the module is loaded, otherwise
                        %% the trace_pattern won't match anything
                        %% and we won't get any traces.
                        case code:ensure_loaded(M) of
                            {module, _} ->
                                case erlang:trace_pattern(MFA, true, [local]) of
                                    0 ->
                                        {error, {undef, MFA}};
                                    _ ->
                                        ok
                                end;
                            {error, Reason} ->
                                {error, {failed_to_load_module, M, Reason}}
                        end;
                   (_MFA, {error, _} = Error) ->
                        Error
                end,
                ok,
                MFAs).

remove_trace_on_all_mfas(MFAs) ->
    [erlang:trace_pattern(MFA, false, [local]) || MFA <- MFAs].

i_end_session(#state{mock_mfas=MockMFAs, watch_mfas=WatchMFAs,
                     session_mref=MRef} = State) ->
    MockMods = get_unique_mods_by_mfas(MockMFAs),
    TraceMFAs = get_trace_mfas(WatchMFAs, MockMods),
    remove_trace_on_all_mfas(TraceMFAs),
    unload_mods(MockMods),
    erlang:trace(all, false, [call, {tracer, self()}]),
    if MRef =/= undefined -> erlang:demonitor(MRef, [flush]);
       true               -> ok
    end,
    State#state{actions=[], calls=[], session_mref=undefined, call_waiters=[],
                mock_mfas=[], watch_mfas=[]}.

i_end_session_and_possibly_dequeue(State0) ->
    State1 = i_end_session(State0),
    State = possibly_dequeue_session(State1),
    case is_within_session(State) of
        true  -> {session, State};
        false -> {no_session, State}
    end.

register_call(MFA, State0) ->
    State1 = store_call(MFA, State0),
    possibly_notify_waiters(State1).

store_call({M, F, A}, #state{calls=Calls} = State) ->
    State#state{calls=[#call{m=M, f=F, a=A} | Calls]}.

possibly_notify_waiters(#state{call_waiters=Waiters0} = State) ->
    Waiters =
        lists:filter(fun(#call_waiter{from=From, mfa=MFA, crit=Criteria}) ->
                             case get_and_check_matches(MFA, Criteria, State) of
                                 {ok, _} = Reply ->
                                     gen_server:reply(From, Reply),
                                     false; % remove from waiting list
                                 {error, _} ->
                                     true   % keep in waiting list
                             end
                     end,
                     Waiters0),
    State#state{call_waiters=Waiters}.

get_and_check_matches(ExpectMFA, Criteria, State) ->
    Matches = get_matches(ExpectMFA, State),
    case check_criteria(Criteria, length(Matches)) of
        ok ->
            {ok, Matches};
        {error, _} = Error ->
            Error
    end.

get_matches({_M, _F, _A}=ExpectMFA, #state{calls=Calls}) ->
    lists:foldl(fun(#call{m=M0, f=F0, a=A0}, Matches) ->
                        case is_match({M0,F0,A0}, ExpectMFA) of
                            true  -> [A0 | Matches];
                            false -> Matches
                        end
                end,
                [],
                Calls).

remove_matching_calls({_M, _F, _A} = ExpectMFA, #state{calls=Calls0}=State) ->
    Calls = lists:filter(fun(#call{m=M0, f=F0, a=A0}) ->
                                 not is_match({M0,F0,A0}, ExpectMFA)
                         end,
                         Calls0),
    State#state{calls=Calls}.

is_match({CallM,CallF,CallA}, {ExpectM,ExpectF,ExpectA}) when CallM==ExpectM,
                                                              CallF==ExpectF ->
    try
        apply(ExpectA, CallA),
        true
    catch
        error:function_clause -> % when guards don't match
            false;
        error:{badarity, _} ->        % when arity doesn't match
            false;
        error:{badmatch, _} ->   % when previously bound vars don't match
            false
    end;
is_match(_CallMFA, _ExpectMFA) ->
    false.

%% @private
check_criteria(Criteria, N) ->
    case check_criteria_syntax(Criteria) of
        ok               -> check_criteria_value(Criteria, N);
        {error, _}=Error -> Error
    end.

check_criteria_syntax(once)                             -> ok;
check_criteria_syntax({at_least, N}) when is_integer(N) -> ok;
check_criteria_syntax({at_most, N}) when is_integer(N)  -> ok;
check_criteria_syntax({times, N}) when is_integer(N)    -> ok;
check_criteria_syntax(never)                            -> ok;
check_criteria_syntax(Criteria) ->
    {error, {invalid_criteria, Criteria}}.

check_criteria_value(once, 1)                      -> ok;
check_criteria_value({at_least, N}, X) when X >= N -> ok;
check_criteria_value({at_most, N}, X) when X =< N  -> ok;
check_criteria_value({times, N}, N)                -> ok;
check_criteria_value(never, 0)                     -> ok;
check_criteria_value(Criteria, N) ->
    Reason = case classify_relation_to_target_value(Criteria, N) of
                 fewer -> fewer_calls_than_expected;
                 more  -> more_calls_than_expected
             end,
    {error, {Reason, {expected, Criteria}, {actual, N}}}.

classify_relation_to_target_value(once, X) when X < 1          -> fewer;
classify_relation_to_target_value(once, X) when X > 1          -> more;
classify_relation_to_target_value({at_least, N}, X) when X < N -> fewer;
classify_relation_to_target_value({at_most, N}, X) when X > N  -> more;
classify_relation_to_target_value({times, N}, X) when X < N    -> fewer;
classify_relation_to_target_value({times, N}, X) when X > N    -> more;
classify_relation_to_target_value(never, X) when X < 0         -> fewer;
classify_relation_to_target_value(never, X) when X > 0         -> more.

i_get_action({M,F,Args}, #state{actions=Actions}) ->
    A = length(Args),
    case lists:keysearch({M,F,A}, #action.mfa, Actions) of
        {value, #action{func=ActionFun}} -> ActionFun;
        false                            -> undefined
    end.

i_set_action({M, F, ActionFun}, _Opts, #state{actions=Actions0} = State) ->
    {arity, A} = erlang:fun_info(ActionFun, arity),
    MFA = {M, F, A},
    case erlang:is_builtin(M, F, A) of
        true ->
            {{error, {cannot_mock_bif, MFA}}, State};
        false ->
            Actions = lists:keystore(MFA, #action.mfa, Actions0,
                                     #action{mfa=MFA, func=ActionFun}),
            {ok, State#state{actions=Actions}}
    end.

i_forget_action({M, F, ActionFun}, #state{actions=Actions0} = State) ->
    {arity, A} = erlang:fun_info(ActionFun, arity),
    MFA = {M, F, A},
    Actions = lists:keydelete(MFA, #action.mfa, Actions0),
    State#state{actions=Actions}.

wait_until_trace_delivered() ->
    Ref = erlang:trace_delivered(all),
    receive {trace_delivered, _, Ref} -> ok end.

chk(ok)                        -> ok;
chk({ok, Value})               -> Value;
chk({error, Reason})           -> erlang:error(Reason);
chk({error, Reason, Location}) -> erlang:error({{reason, Reason},
                                                {location, Location}}).

possibly_add_location({error, Reason}, Opts) ->
    case proplists:get_value(location, Opts) of
        undefined -> {error, Reason};
        Location  -> {error, Reason, Location}
    end;
possibly_add_location({ok, _}=OkRes, _Opts) ->
    OkRes.


mock_and_load_mods(MFAs) ->
    ModsFAs = group_fas_by_mod(MFAs),
    lists:foreach(fun(ModFAs) -> mock_and_load_mod(ModFAs) end,
                  ModsFAs).

mock_and_load_mod(ModFAs) ->
    {Mod, Bin} = mk_or_retrieve_mocked_mod(ModFAs),
    {module, Mod} = code:load_binary(Mod, "mock", Bin).

mk_or_retrieve_mocked_mod({Mod, UserAddedFAs}) ->
    case get_exported_fas_and_object_code(Mod) of
        {ok, {ExportedFAs, Bin, Filename}} ->
            ok = possibly_unstick_mod(Mod),
            OrigMod = reload_mod_under_different_name(Mod, Bin, Filename),
            OrigHash = get_module_checksum(OrigMod),
            FAs = get_non_bif_fas(Mod, lists:usort(ExportedFAs++UserAddedFAs)),
            case retrieve_mocking_mod(Mod, OrigHash) of
                {ok, MockingMod} ->
                    MockingMod;
                undefined ->
                    MockingMod = mk_mocking_mod(Mod, OrigMod, FAs),
                    store_mocking_mod(MockingMod, OrigHash),
                    MockingMod
            end;
        {error, {no_such_module, Mod}} ->
            mk_new_mod(Mod, UserAddedFAs)
    end.

get_module_checksum(Mod) ->
    try
        %% This macro was introduced in Erlang/OTP 18.0.
        Mod:module_info(md5)
    catch
        error:badarg ->
            %% This is a workaround for older releases.
            {ok, {_Mod, Md5}} = beam_lib:md5(code:which(Mod)),
            Md5
    end.

create_mocking_mod_cache() ->
    ets:new(?CACHE_TAB, [named_table]).

store_mocking_mod({Mod, Bin}, Hash) ->
    true = ets:insert_new(?CACHE_TAB, {{Mod, Hash}, Bin}).

retrieve_mocking_mod(Mod, Hash) ->
    case ets:lookup(?CACHE_TAB, {Mod, Hash}) of
        [] ->
            undefined;
        [{_, Bin}] ->
            {ok, {Mod, Bin}}
    end.

destroy_mocking_mod_cache() ->
    ets:delete(?CACHE_TAB).

possibly_unstick_mod(Mod) ->
    case code:is_sticky(Mod) of
        true ->
            case code:which(Mod) of
                Filename when is_list(Filename) ->
                    case code:unstick_dir(filename:dirname(Filename)) of
                        ok ->
                            ok;
                        error ->
                            erlang:error({failed_to_unstick_module, Mod})
                    end;
                Other ->
                    erlang:error({failed_to_unstick_module, Mod,
                                  {code_which_output, Other}})
            end;
        false ->
            ok
    end.

reload_mod_under_different_name(Mod, OrigBin0, Filename) ->
    {module, Mod} = code:ensure_loaded(Mod),
    OrigMod = list_to_atom(atom_to_list(Mod)++"^"),
    OrigBin = rename(OrigBin0, OrigMod),
    unload_mod(Mod),
    {module, OrigMod} = code:load_binary(OrigMod, Filename, OrigBin),
    OrigMod.

mk_mocking_mod(Mod, OrigMod, ExportedFAs) ->
    mk_mod(Mod, mk_mocked_funcs(Mod, OrigMod, ExportedFAs)).

mk_mocked_funcs(Mod, OrigMod, ExportedFAs) ->
    lists:map(fun(ExportedFA) -> mk_mocked_func(Mod, OrigMod, ExportedFA) end,
              ExportedFAs).

mk_mocked_func(Mod, OrigMod, {F, A}) ->
    %% Generate a function like this (mod, func and arguments vary):
    %%
    %%     func(A2, A1) ->
    %%         case mockgyver:reg_call_and_get_action({mod,func,[A2, A1]}) of
    %%             undefined ->
    %%                 'mod^':func(A2, A1);
    %%             ActionFun ->
    %%                 ActionFun(A2, A1)
    %%         end.
    Args = mk_args(A),
    Body =[erl_syntax:case_expr(
             mk_call(mockgyver, reg_call_and_get_action,
                     [erl_syntax:tuple([erl_syntax:abstract(Mod),
                                        erl_syntax:abstract(F),
                                        erl_syntax:list(Args)])]),
             [erl_syntax:clause([erl_syntax:atom(undefined)],
                                none,
                                [mk_call(OrigMod, F, Args)]),
              erl_syntax:clause([erl_syntax:variable('ActionFun')],
                                none,
                                [mk_call('ActionFun', Args)])])],
    erl_syntax:function(
      erl_syntax:abstract(F),
      [erl_syntax:clause(Args, none, Body)]).

mk_new_mod(Mod, ExportedFAs) ->
    mk_mod(Mod, mk_new_funcs(Mod, ExportedFAs)).

mk_new_funcs(Mod, ExportedFAs) ->
    lists:map(fun(ExportedFA) -> mk_new_func(Mod, ExportedFA) end,
              ExportedFAs).

mk_new_func(Mod, {F, A}) ->
    %% Generate a function like this (mod, func and arguments vary):
    %%
    %%     func(A2, A1) ->
    %%         case mockgyver:reg_call_and_get_action({mod,func,[A2, A1]}) of
    %%             undefined ->
    %%                 erlang:error(undef); % emulate undefined function
    %%             ActionFun ->
    %%                 ActionFun(A2, A1)
    %%         end.
    Args = mk_args(A),
    Body =[erl_syntax:case_expr(
             mk_call(mockgyver, reg_call_and_get_action,
                     [erl_syntax:tuple([erl_syntax:abstract(Mod),
                                        erl_syntax:abstract(F),
                                        erl_syntax:list(Args)])]),
             [erl_syntax:clause([erl_syntax:atom(undefined)],
                                none,
                                [mk_call(erlang, error,
                                         [erl_syntax:atom(undef)])]),
              erl_syntax:clause([erl_syntax:variable('ActionFun')],
                                none,
                                [mk_call('ActionFun', Args)])])],
    erl_syntax:function(
      erl_syntax:abstract(F),
      [erl_syntax:clause(Args, none, Body)]).

mk_mod(Mod, FuncForms) ->
    Forms0 = ([erl_syntax:attribute(erl_syntax:abstract(module),
                                    [erl_syntax:abstract(Mod)])]
              ++ FuncForms),
    Forms = [erl_syntax:revert(Form) || Form <- Forms0],
    %%io:format("--------------------------------------------------~n"
    %%          "~s~n",
    %%          [[erl_pp:form(Form) || Form <- Forms]]),
    {ok, Mod, Bin} = compile:forms(Forms, [report, export_all]),
    {Mod, Bin}.

mk_call(FunVar, As) ->
    erl_syntax:application(erl_syntax:variable(FunVar), As).

mk_call(M, F, As) ->
    erl_syntax:application(erl_syntax:abstract(M), erl_syntax:abstract(F), As).

mk_args(0) ->
    [];
mk_args(N) ->
    [mk_arg(N) | mk_args(N-1)].

mk_arg(N) ->
    erl_syntax:variable(list_to_atom("A"++integer_to_list(N))).

unload_mods(Mods) ->
    lists:foreach(fun unload_mod/1, Mods).

unload_mod(Mod) ->
    case code:is_loaded(Mod) of
        {file, _} ->
            code:purge(Mod),
            true = code:delete(Mod);
        false ->
            ok
    end.

get_unique_mods_by_mfas(MFAs) ->
    lists:usort([M || {M,_F,_A} <- MFAs]).

group_fas_by_mod(MFAs) ->
    ModFAs = lists:foldl(fun({M, F, A}, AccModFAs) ->
                                 dict:append(M, {F, A}, AccModFAs)
                         end,
                         dict:new(),
                         MFAs),
    dict:to_list(ModFAs).

get_exported_fas_and_object_code(Mod) ->
    case get_exported_fas(Mod) of
        {ok, FAs} ->
            case code:get_object_code(Mod) of
                {Mod, Bin, Filename} ->
                    {ok, {FAs, Bin, Filename}};
                error ->
                    %% Likely a module dynamically generated and loaded
                    %% on the fly. Unload it first to replace it with new
                    %% contents. It will be impossible to restore such a
                    %% module after mocking has completed anyway.
                    unload_mod(Mod),
                    {error, {no_such_module, Mod}}
            end;
        {error, _}=Error ->
            Error
    end.

get_exported_fas(Mod) ->
    try
        {ok, [{F, A} || {F, A} <- Mod:module_info(exports),
                        {F, A} =/= {module_info, 0},
                        {F, A} =/= {module_info, 1}]}
    catch
        error:undef ->
            {error, {no_such_module, Mod}}
    end.

get_non_bif_fas(Mod, FAs) ->
    [{F, A} || {F, A} <- FAs, not erlang:is_builtin(Mod, F, A)].

%% Calculate the Levenshtein distance between two strings.
%%     http://en.wikipedia.org/wiki/Levenshtein_distance
%%
%% Returns 0 when the strings are identical.  Returns at most a value
%% which is equal to to the length of the longest string.
%%
%% Insertions, deletions and substitutions have the same weight.
calc_levenshtein_dist(S, T) ->
    calc_levenshtein_dist_t(S, T, lists:seq(0, length(S)), 0).

%% Loop over the target string and calculate rows in the tables you'll
%% find on web pages which describe the algoritm.  S is the source
%% string, T the target string, Ds0 is the list of distances for the
%% previous row and J is the base for the leftmost column.
calc_levenshtein_dist_t(S, [_|TT]=T, Ds0, J) ->
    Ds = calc_levenshtein_dist_s(S, T, Ds0, [J+1], J),
    calc_levenshtein_dist_t(S, TT, Ds, J+1);
calc_levenshtein_dist_t(_S, [], Ds, _J) ->
    hd(lists:reverse(Ds)).

%% Loop over the source string and calculate the columns for a
%% specific row in the tables you'll find on web pages which describe
%% the algoritm.
calc_levenshtein_dist_s([SH|ST], [TH|_]=T, [DH|DT], AccDs, PrevD) ->
    NextD = if SH==TH -> DH;
               true   -> lists:min([PrevD+1,  % deletion
                                    hd(DT)+1, % insertion
                                    DH+1])    % substitution
            end,
    calc_levenshtein_dist_s(ST, T, DT, [NextD|AccDs], NextD);
calc_levenshtein_dist_s([], _T, _Ds, AccDs, _PrevD) ->
    lists:reverse(AccDs).


f(Format, Args) ->
    lists:flatten(io_lib:format(Format, Args)).

%%-------------------------------------------------------------------
%% Rename a module which is already compiled.
%%-------------------------------------------------------------------

%% The idea behind `beam_renamer` is to be able to load an erlang module
%% (which is already compiled) under a different name.  Normally, there's
%% an error message if one does that:
%%
%%     1> {x, Bin, _} = code:get_object_code(x).
%%     {x,<<...>>,...}
%%     2> code:load_binary(y, "y.beam", Bin).
%%     {error,badfile}
%%
%%     =ERROR REPORT==== 8-Nov-2009::22:01:24 ===
%%     Loading of y.beam failed: badfile
%%
%%     =ERROR REPORT==== 8-Nov-2009::22:01:24 ===
%%     beam/beam_load.c(1022): Error loading module y:
%%       module name in object code is x
%%
%% This is where `beam_renamer` comes in handy.  It'll rename the module
%% by replacing the module name *within* the beam file.
%%
%%     1> {x, Bin0, _} = code:get_object_code(x).
%%     {x,<<...>>,...}
%%     2> Bin = beam_renamer:rename(Bin0, y).
%%     <<...>>
%%     2> code:load_binary(y, "y.beam", Bin).
%%     {module,y}

%% In order to load a module under a different name, the module name
%% has to be changed within the beam file itself.  The following code
%% snippet does just that.  It's based on a specification of the beam
%% format (a fairly old one, from March 1 2000, but it seems there are
%% not changes changes which affect the code below):
%%
%%      http://www.erlang.se/~bjorn/beam_file_format.html
%%
%% BEWARE of modules which refer to themselves!  This is where things
%% start to become interesting...  If ?MODULE is used in a function
%% call, things should be ok (the module name is replaced in the
%% function call).  The same goes for a ?MODULE which stands on its
%% own in a statement (like the sole return value).  But if it's
%% embedded for example within a tuple or list with only constant
%% values, it's added to the constant pool which is a separate chunk
%% within the beam file.  The current code doesn't replace occurences
%% within the constant pool.  Although possible, I'll leave that for
%% later. :-)
%%
%% The rename function does two things: It replaces the first atom of
%% the atom table (since apparently that's where the module name is).
%% Since the new name may be shorter or longer than the old name, one
%% might have to adjust the length of the atom table chunk
%% accordingly.  Finally it updates the top-level form size, since the
%% atom table chunk might have grown or shrunk.
%%
%% From the above beam format specification:
%%
%%     This file format is based on EA IFF 85 - Standard for
%%     Interchange Format Files. This "standard" is not widely used;
%%     the only uses I know of is the IFF graphic file format for the
%%     Amiga and Blorb (a resource file format for Interactive Fiction
%%     games). Despite of this, I decided to use IFF instead of
%%     inventing my of own format, because IFF is almost right.
%%
%%     The only thing that is not right is the even alignment of
%%     chunks. I use four-byte alignment instead. Because of this
%%     change, Beam files starts with 'FOR1' instead of 'FORM' to
%%     allow reader programs to distinguish "classic" IFF from "beam"
%%     IFF. The name 'FOR1' is included in the IFF document as a
%%     future way to extend IFF.
%%
%%     In the description of the chunks that follow, the word
%%     mandatory means that the module cannot be loaded without it.
%%
%%
%%     FORM HEADER
%%
%%     4 bytes    'FOR1'  Magic number indicating an IFF form. This is an
%%                        extension to IFF indicating that all chunks are
%%                        four-byte aligned.
%%     4 bytes    n       Form length (file length - 8)
%%     4 bytes    'BEAM'  Form type
%%     n-8 bytes  ...     The chunks, concatenated.
%%
%%
%%     ATOM TABLE CHUNK
%%
%%     The atom table chunk is mandatory. The first atom in the table must
%%     be the module name.
%%
%%     4 bytes    'Atom'
%%          or    'AtU8'  chunk ID
%%     4 bytes    size    total chunk length
%%     4 bytes    n       number of atoms
%%     xx bytes   ...     Atoms. Each atom is a string preceeded
%%                        by the length in a byte, encoded
%%                        in latin1 (if chunk ID == 'Atom') or
%%                        or UTF-8 (if chunk ID == 'AtU8')
%%
%% The following section about the constant pool (literal table) was
%% reverse engineered from the source (beam_lib etc), since it wasn't
%% included in the beam format specification referred above.
%%
%%     CONSTANT POOL/LITERAL TABLE CHUNK
%%
%%     The literal table chunk is optional.
%%
%%     4 bytes    'LitT'  chunk ID
%%     4 bytes    size    total chunk length
%%     4 bytes    size    size of uncompressed constants
%%     xx bytes   ...     zlib compressed constants
%%
%%     Once uncompressed, the format of the constants are as follows:
%%
%%     4 bytes    size    unknown
%%     4 bytes    size    size of first literal
%%     xx bytes   ...     term_to_binary encoded literal
%%     4 bytes    size    size of next literal
%%     ...

%%--------------------------------------------------------------------
%% @spec rename(BeamBin0, NewName) -> BeamBin
%%         BeamBin0 = binary()
%%         BeamBin = binary()
%%         NewName = atom()
%% @doc Rename a module.  `BeamBin0' is a binary containing the
%% contents of the beam file.
%% @end
%%--------------------------------------------------------------------
rename(BeamBin0, Name) ->
    BeamBin = replace_in_atab(BeamBin0, Name),
    update_form_size(BeamBin).

%% Replace the first atom of the atom table with the new name
replace_in_atab(<<"Atom", CnkSz0:32, Cnk:CnkSz0/binary, Rest/binary>>, Name) ->
    replace_first_atom(<<"Atom">>, Cnk, CnkSz0, Rest, latin1, Name);
replace_in_atab(<<"AtU8", CnkSz0:32, Cnk:CnkSz0/binary, Rest/binary>>, Name) ->
    replace_first_atom(<<"AtU8">>, Cnk, CnkSz0, Rest, unicode, Name);
replace_in_atab(<<C, Rest/binary>>, Name) ->
    <<C, (replace_in_atab(Rest, Name))/binary>>.

replace_first_atom(CnkName, Cnk, CnkSz0, Rest, Encoding, Name) ->
    <<NumAtoms:32, NameSz0:8, _Name0:NameSz0/binary, CnkRest/binary>> = Cnk,
    NumPad0 = num_pad_bytes(CnkSz0),
    <<_:NumPad0/unit:8, NextCnks/binary>> = Rest,
    NameBin = atom_to_binary(Name, Encoding),
    NameSz = byte_size(NameBin),
    CnkSz = CnkSz0 + NameSz - NameSz0,
    NumPad = num_pad_bytes(CnkSz),
    <<CnkName/binary, CnkSz:32, NumAtoms:32, NameSz:8, NameBin:NameSz/binary,
      CnkRest/binary, 0:NumPad/unit:8, NextCnks/binary>>.


%% Calculate the number of padding bytes that have to be added for the
%% BinSize to be an even multiple of ?beam_num_bytes_alignment.
num_pad_bytes(BinSize) ->
    case ?beam_num_bytes_alignment - (BinSize rem ?beam_num_bytes_alignment) of
        4 -> 0;
        N -> N
    end.

%% Update the size within the top-level form
update_form_size(<<"FOR1", _OldSz:32, Rest/binary>> = Bin) ->
    Sz = size(Bin) - 8,
    <<"FOR1", Sz:32, Rest/binary>>.
