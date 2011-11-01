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
%%% ```
%%%     ?WHEN(module:function(Arg1, Arg2, ...) -> Expr),
%%% '''
%%%
%%% where `Expr' is a single expression (like a term) or a series of
%%% expressions surrounded by `begin' and `end'.
%%%
%%% ==== ?FORGET_WHEN syntax ====
%%% ```
%%%     ?FORGET_WHEN(module:function(_, _, ...)),
%%% '''
%%%
%%% The only things of interest are the name of the module, the name
%%% of the function and the arity.  The arguments of the function are
%%% ignored and it can be a wise idea to set these to the "don't care"
%%% variable: underscore.
%%%
%%% ==== Examples ====
%%% Redefine pi to 4:
%%% ```
%%%     ?WHEN(math:pi() -> 4),
%%% '''
%%% Implement a mock with multiple clauses:
%%% ```
%%%     ?WHEN(my_module:classify_number(N) when N >= 0 -> positive;
%%%           my_module:classify_number(_N)            -> negative),
%%% '''
%%% Call original module:
%%% ```
%%%     ?WHEN(math:pi() -> 'math^':pi() * 2),
%%% '''
%%% Use a variable bound outside the mock:
%%% ```
%%%     Answer = 42,
%%%     ?WHEN(math:pi() -> Answer),
%%% '''
%%% Redefine the mock:
%%% ```
%%%     ?WHEN(math:pi() -> 4),
%%%     4 = math:pi(),
%%%     ?WHEN(math:pi() -> 5),
%%%     5 = math:pi(),
%%% '''
%%% Let the mock exit with an error:
%%% ```
%%%     ?WHEN(math:pi() -> erlang:error(some_error)),
%%% '''
%%% Make a new module:
%%% ```
%%%     ?WHEN(my_math:pi() -> 4),
%%%     ?WHEN(my_math:e() -> 3),
%%% '''
%%% Put multiple clauses in a function's body:
%%% ```
%%%     ?WHEN(math:pi() ->
%%%               begin
%%%                   do_something1(),
%%%                   do_something2()
%%%               end),
%%% '''
%%% Revert the pi function to its default behaviour (return value from
%%% the original module), any other mocks in the same module, or any
%%% other module are left untouched:
%%% ```
%%%     ?WHEN(math:pi() -> 4),
%%%     4 = math:pi(),
%%%     ?FORGET_WHEN(math:pi()),
%%%     3.1415... = math:pi(),
%%% '''
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
%%%   <li>`?FORGET_CALLS': Forget the calls that have been logged for a
%%%        certain function.  Takes arguments and guards into account,
%%%        i.e. only the calls which match the module name, function
%%%        name and all arguments as well as any guards will be
%%%        forgotten, while the rest of the calls remain.</li>
%%% </ul>
%%%
%%% ==== ?WAS_CALLED syntax ====
%%% ```
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
%%% '''
%%% ==== ?WAIT_CALLED syntax ====
%%%
%%% See syntax for `?WAS_CALLED'.
%%%
%%% ==== ?GET_CALLS syntax ====
%%% ```
%%%     ?GET_CALLS(module:function(Arg1, Arg2, ...)),
%%%
%%%         Result: [CallArgs]
%%%                 CallArgs = [CallArg]
%%%                 CallArg = term()
%%% '''
%%%
%%% ==== ?NUM_CALLS syntax ====
%%% ```
%%%     ?NUM_CALLS(module:function(Arg1, Arg2, ...)),
%%%
%%%         Result: integer()
%%% '''
%%% ==== ?FORGET_CALLS syntax ====
%%% ```
%%%     ?FORGET_CALLS(module:function(Arg1, Arg2, ...)),
%%% '''
%%% ==== Examples ====
%%% Check that a function has been called once (the two alternatives
%%% are equivalent):
%%% ```
%%%     ?WAS_CALLED(math:pi()),
%%%     ?WAS_CALLED(math:pi(), once),
%%% '''
%%% Check that a function has never been called:
%%% ```
%%%     ?WAS_CALLED(math:pi(), never),
%%% '''
%%% Check that a function has been called twice:
%%% ```
%%%     ?WAS_CALLED(math:pi(), {times, 2}),
%%% '''
%%% Check that a function has been called at least twice:
%%% ```
%%%     ?WAS_CALLED(math:pi(), {at_least, 2}),
%%% '''
%%% Check that a function has been called at most twice:
%%% ```
%%%     ?WAS_CALLED(math:pi(), {at_most, 2}),
%%% '''
%%% Use pattern matching to check that a function was called with
%%% certain arguments:
%%% ```
%%%     ?WAS_CALLED(lists:reverse([a, b, c])),
%%% '''
%%% Pattern matching can even use bound variables:
%%% ```
%%%     L = [a, b, c],
%%%     ?WAS_CALLED(lists:reverse(L)),
%%% '''
%%% Use a guard to validate the parameters in a call:
%%% ```
%%%     ?WAS_CALLED(lists:reverse(L) when is_list(L)),
%%% '''
%%% Retrieve the arguments in a call while verifying the number of calls:
%%% ```
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     [[1, [a, b]], [2, [c, d]]] = ?WAS_CALLED(lists:nth(_, _), {times, 2}),
%%% '''
%%% Retrieve the arguments in a call without verifying the number of calls:
%%% ```
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     [[1, [a, b]], [2, [c, d]]] = ?GET_CALLS(lists:nth(_, _)),
%%% '''
%%% Retrieve the number of calls:
%%% ```
%%%     a = lists:nth(1, [a, b]),
%%%     d = lists:nth(2, [c, d]),
%%%     2 = ?NUM_CALLS(lists:nth(_, _)),
%%% '''
%%% Forget calls to functions:
%%% ```
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
%%% '''
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver).

-behaviour(gen_server).

%% This transform makes it easier for this module to generate code.
%% Depends on a 3pp library (http://github.com/esl/parse_trans).
-compile({parse_transform, parse_trans_codegen}).

%% API
-export([exec/3]).

-export([start_link/0]).
-export([stop/0]).

-export([reg_call_and_get_action/1, get_action/1, set_action/1]).
-export([verify/2]).

%% For test
-export([check_criteria/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-define(beam_num_bytes_alignment, 4). %% according to spec below

-record(state, {actions=[], calls, session_mref, session_waiters=queue:new(),
                call_waiters=[], mock_mfas=[], watch_mfas=[]}).
-record(call, {m, f, a}).
-record(action, {mfa, func}).
-record(call_waiter, {from, mfa, crit}).

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
    call({reg_call_and_get_action, MFA}).

%% @private
get_action(MFA) ->
    call({get_action, MFA}).

%% @private
set_action(MFA) ->
    chk(call({set_action, MFA})).

%% @private
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, {}, []).

%% @private
stop() ->
    call(stop).

ensure_application_started() ->
    case application:start(?MODULE) of
        ok                            -> ok;
        {error, {already_started, _}} -> ok;
        {error, _} = Error            -> Error
    end.

start_session(MockMFAs, WatchMFAs) ->
    call({start_session, MockMFAs, WatchMFAs, self()}).

end_session() ->
    call(end_session).

%% @private
%% once | {at_least, N} | {at_most, N} | {times, N} | never
verify({M, F, A}, Criteria) ->
    wait_until_trace_delivered(),
    chk(call({verify, {M, F, A}, Criteria})).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init({}) ->
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call({start_session, MockMFAs, WatchMFAs, Pid}, From, State0) ->
    case is_within_session(State0) of
        false ->
            {Reply, State} = i_start_session(MockMFAs, WatchMFAs, Pid, State0),
            {reply, Reply, State};
        true ->
            {noreply, enqueue_session({From, MockMFAs, WatchMFAs, Pid}, State0)}
    end;
handle_call(end_session, _From, State0) ->
    State1 = i_end_session(State0),
    State = possibly_dequeue_session(State1),
    {reply, ok, State};
handle_call({reg_call_and_get_action, MFA}, _From, State0) ->
    State = register_call(MFA, State0),
    ActionFun = i_get_action(MFA, State),
    {reply, ActionFun, State};
handle_call({get_action, MFA}, _From, State) ->
    ActionFun = i_get_action(MFA, State),
    {reply, ActionFun, State};
handle_call({set_action, MFA}, _From, State0) ->
    {Reply, State} = i_set_action(MFA, State0),
    {reply, Reply, State};
handle_call({verify, MFA, {was_called, Criteria}}, _From, State) ->
    Reply = get_and_check_matches(MFA, Criteria, State),
    {reply, Reply, State};
handle_call({verify, MFA, {wait_called, Criteria}}, From, State) ->
    case get_and_check_matches(MFA, Criteria, State) of
        {ok, _} = Reply ->
            {reply, Reply, State};
        {error, {criteria_not_fulfilled, _, _}} ->
            Waiters = State#state.call_waiters,
            Waiter  = #call_waiter{from=From, mfa=MFA, crit=Criteria},
            {noreply, State#state{call_waiters = [Waiter | Waiters]}};
        {error, _} = Error ->
            {reply, Error, State}
    end;
handle_call({verify, MFA, num_calls}, _From, State) ->
    Matches = get_matches(MFA, State),
    {reply, {ok, length(Matches)}, State};
handle_call({verify, MFA, get_calls}, _From, State) ->
    Matches = get_matches(MFA, State),
    {reply, {ok, Matches}, State};
handle_call({verify, MFA, forget_when}, _From, State0) ->
    State = i_forget_action(MFA, State0),
    {reply, ok, State};
handle_call({verify, MFA, forget_calls}, _From, State0) ->
    State = remove_matching_calls(MFA, State0),
    {reply, ok, State};
handle_call(stop, _From, State) ->
    {stop, normal, ok, State}.

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

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(#'DOWN'{mref=MRef}, #state{session_mref=MRef,
                                       call_waiters=Waiters,
                                       calls=Calls}=State0) ->
    %% The test died before it got a chance to clean up after itself.
    %% Check whether there are any pending waiters.  If so, just print
    %% the calls we've logged so far.  Hopefully that helps in
    %% debugging.  This is probably the best we can accomplish -- being
    %% able to fail the eunit test would be nice.  Another day perhaps.
    possibly_print_call_waiters(Waiters, Calls),
    State = i_end_session(State0),
    {noreply, State};
handle_info({trace, _, call, MFA}, State0) ->
    State = register_call(MFA, State0),
    {noreply, State};
handle_info(Info, State) ->
    io:format(user, "~p got message: ~p~n", [?MODULE, Info]),
    {noreply, State}.

possibly_print_call_waiters([], _Calls) ->
    ok;
possibly_print_call_waiters(_Waiters, Calls) ->
    io:format(user,
              "Test died while waiting for a call.~n"
              "    Calls so far: ~p~n",
              [[{M, F, A} || #call{m=M, f=F, a=A} <- Calls]]).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

call(Msg) ->
    gen_server:call(?SERVER, Msg, infinity).

i_start_session(MockMFAs, WatchMFAs, Pid, State0) ->
    State = State0#state{mock_mfas=MockMFAs, watch_mfas=WatchMFAs},
    MockMods = get_unique_mods_by_mfas(MockMFAs),
    mock_and_load_mods(MockMFAs),
    erlang:trace(all, true, [call, {tracer, self()}]),
    %% We mustn't trace non-mocked modules, since we'll register
    %% calls for those as part of reg_call_and_get_action.  If we
    %% did, we'd get double the amount of calls.
    TraceMFAs = [{M,F,A} || {M,F,A} <- WatchMFAs,
                            not lists:member(M, MockMods)],
    case setup_trace_on_all_mfas(TraceMFAs) of
        ok ->
            MRef = erlang:monitor(process, Pid),
            {ok, State#state{calls=[], session_mref=MRef}};
        {error, _}=Error ->
            {Error, i_end_session(State)}
    end.

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

i_end_session(#state{mock_mfas=MockMFAs, session_mref=MRef} = State) ->
    unload_mods(get_unique_mods_by_mfas(MockMFAs)),
    erlang:trace(all, false, [call, {tracer, self()}]),
    if MRef =/= undefined -> erlang:demonitor(MRef, [flush]);
       true               -> ok
    end,
    State#state{actions=[], calls=[], session_mref=undefined, call_waiters=[],
                mock_mfas=[], watch_mfas=[]}.

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
        ExpectA(CallA),
        true
    catch
        error:function_clause -> % when arity or guards don't match
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
    {error, {criteria_not_fulfilled, {expected, Criteria}, {actual, N}}}.

i_get_action({M,F,Args}, #state{actions=Actions}) ->
    A = length(Args),
    case lists:keysearch({M,F,A}, #action.mfa, Actions) of
        {value, #action{func=ActionFun}} -> ActionFun;
        false                            -> undefined
    end.

i_set_action({M, F, ActionFun}, #state{actions=Actions0} = State) ->
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

chk(ok)              -> ok;
chk({ok, Value})     -> Value;
chk({error, Reason}) -> erlang:error(Reason).

mock_and_load_mods(MFAs) ->
    ModsFAs = group_fas_by_mod(MFAs),
    lists:foreach(fun(ModFAs) -> mock_and_load_mod(ModFAs) end,
                  ModsFAs).

mock_and_load_mod({Mod, UserAddedFAs}) ->
    case get_exported_fas(Mod) of
        {ok, ExportedFAs} ->
            OrigMod = reload_mod_under_different_name(Mod),
            FAs = get_non_bif_fas(Mod, lists:usort(ExportedFAs++UserAddedFAs)),
            mk_mocking_mod(Mod, OrigMod, FAs);
        {error, {no_such_module, Mod}} ->
            mk_new_mod(Mod, UserAddedFAs)
    end.

reload_mod_under_different_name(Mod) ->
    {module, Mod} = code:ensure_loaded(Mod),
    {Mod, OrigBin0, Filename} = code:get_object_code(Mod),
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
    {ok, Mod, Bin} = compile:forms(Forms, [report, export_all]),
    {module, Mod} = code:load_binary(Mod, "mock", Bin).

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
%%     4 bytes    'Atom'  chunk ID
%%     4 bytes    size    total chunk length
%%     4 bytes    n       number of atoms
%%     xx bytes   ...     Atoms. Each atom is a string preceeded
%%                        by the length in a byte.
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
    NameBin = atom_to_binary(Name, latin1),
    BeamBin = replace_in_atab(BeamBin0, NameBin),
    update_form_size(BeamBin).

%% Replace the first atom of the atom table with the new name
replace_in_atab(<<"Atom", CnkSz0:32, Cnk:CnkSz0/binary, Rest/binary>>, Name) ->
    <<NumAtoms:32, NameSz0:8, _Name0:NameSz0/binary, CnkRest/binary>> = Cnk,
    NumPad0 = num_pad_bytes(CnkSz0),
    <<_:NumPad0/unit:8, NextCnks/binary>> = Rest,
    NameSz = size(Name),
    CnkSz = CnkSz0 + NameSz - NameSz0,
    NumPad = num_pad_bytes(CnkSz),
    <<"Atom", CnkSz:32, NumAtoms:32, NameSz:8, Name:NameSz/binary,
     CnkRest/binary, 0:NumPad/unit:8, NextCnks/binary>>;
replace_in_atab(<<C, Rest/binary>>, Name) ->
    <<C, (replace_in_atab(Rest, Name))/binary>>.

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
