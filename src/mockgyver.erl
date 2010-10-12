%%%-------------------------------------------------------------------
%%% @author Klas Johansson klas.johansson@gmail.com
%%% @copyright (C) 2010, Klas Johansson
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver).

-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([stop/0]).

-export([start_session/1]).

-export([was_called/1, was_called/2]).

-export([test/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE). 

-record(state, {subs, calls, mref}).
-record(call, {m, f, a}).
%-record(sub, {call, effect}).

%-record(trace, {msg}).
-record('DOWN', {mref, type, obj, info}).

%%%===================================================================
%%% API
%%%===================================================================

test(X) ->
    X.

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
    call(stop).

start_session(MfaPatterns) ->
    call({start_session, MfaPatterns, self()}).

was_called({M, F, A}) ->
    was_called({M, F, A}, once).

%% once | {at_least, N} | {at_most, N} | {times, N} | never
was_called({M, F, A}, Criteria) ->
    wait_until_trace_delivered(),
    chk(call({was_called, {M, F, A}, Criteria})).


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
init([]) ->
    %% dbg:stop_clear(),
    %% dbg:tracer(process, {mk_tracer_fun(self()), dummy}),
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
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call({start_session, MfaPatterns, Pid}, _From, State0) ->
    State = i_start_session(MfaPatterns, Pid, State0),
    {reply, ok, State};
handle_call({was_called, MFA, Criteria}, _From, State) ->
    Reply = i_was_called(MFA, Criteria, State),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

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
handle_info(#'DOWN'{mref=MRef}, #state{mref=MRef} = State0) ->
    State = i_end_session(State0),
    {noreply, State};
handle_info({trace, _, call, MFA}, State0) ->
    State = i_reg_call(MFA, State0),
    {noreply, State};
handle_info(Info, State) ->
    io:format(user, "==> ~p~n", [Info]),
    {noreply, State}.

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
    gen_server:call(?SERVER, Msg).

mk_tracer_fun(Parent) ->
    fun(Msg, State) ->
            Parent ! Msg,
            State
    end.

i_start_session(Mfas, Pid, State) ->
%    dbg:p(all, c),
    %% lists:foreach(fun(MfaPattern) -> apply(dbg, tpl, MfaPattern) end,
    %%               MfaPatterns),
    erlang:trace(all, true, [call, {tracer, self()}]),
    lists:foreach(fun({M,_F,_A} = Mfa) ->
                          %% Ensure the module is loaded, otherwise
                          %% the trace_pattern won't match anything
                          %% and we won't get any traces.
                          {module, _} = code:ensure_loaded(M),
                          1 = erlang:trace_pattern(Mfa, true, [local])
                  end,
                  Mfas),
    MRef = erlang:monitor(process, Pid),
    State#state{calls=[], mref=MRef}.

i_end_session(State) ->
%%    dbg:ctpl(),
    erlang:trace(all, false, [call, {tracer, self()}]),
    State#state{mref=undefined}.

i_reg_call({M, F, A}, #state{calls=Calls} = State) ->
    State#state{calls=[#call{m=M, f=F, a=A} | Calls]}.

i_was_called(MFA, Criteria, State) ->
    NumMatches = count_matches(MFA, State),
    check_criteria(Criteria, NumMatches).

count_matches({M, F, A}, #state{calls=Calls}) ->
    lists:foldl(fun(#call{m=M0, f=F0, a=A0}, Num) when M0 =:= M, F0 =:= F ->
%                        io:format(user, "--> ~p ~~ ~p? --> ~p~n", [A0, A, erlang:match_spec_test(A0, A, trace)]),
                        case erlang:match_spec_test(A0, A, trace) of
                            {ok, true,  _Warnings, _Flags} -> Num+1;
                            {ok, false, _Warnings, _Flags} -> Num
                        end;
                   (_, Num) ->
                        Num
                end,
                0,
                Calls).

check_criteria(once, 1)                      -> ok;
check_criteria({at_least, N}, X) when X >= N -> ok;
check_criteria({at_most, N}, X) when X =< N  -> ok;
check_criteria({times, N}, N)                -> ok;
check_criteria(never, 0)                     -> ok;
check_criteria(Criteria, N) ->
    {error, {criteria_not_fulfilled, Criteria, N}}.




%% ms_transform:transform_from_shell(dbg, [{clause,1,
%% 139>                           [{cons,1,
%% 139>                                  {integer,1,1},
%% 139>                                  {cons,1,{integer,1,2},{nil,1}}}],
%% 139>                           [],
%% 139>                           [{atom,1,ok}]}], []).
%% [{[1,2],[],[ok]}]


%% element(2,erl_parse:parse_exprs(element(2, erl_scan:string("fun([1,2]) -> ok end.")))).

wait_until_trace_delivered() ->
    Ref = erlang:trace_delivered(all),
    receive {trace_delivered, _, Ref} -> ok end.

chk(ok)              -> ok;
chk({ok, _} = Ok)    -> Ok;
chk({error, Reason}) -> erlang:error(Reason).
