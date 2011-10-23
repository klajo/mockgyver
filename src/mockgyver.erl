%%%-------------------------------------------------------------------
%%% @author Klas Johansson klas.johansson@gmail.com
%%% @copyright (C) 2010, Klas Johansson
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver).

-behaviour(gen_server).

%% This transform makes it easier for this module to generate code.
%% Depends on a 3pp library (http://github.com/esl/parse_trans).
-compile({parse_transform, parse_trans_codegen}).

%% API
-export([exec/3]).

-export([start/0]).
-export([stop/0]).

-export([start_session/2]).

-export([get_action/1, set_action/1]).
-export([verify/2]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(SERVER, ?MODULE).

-define(beam_num_bytes_alignment, 4). %% according to spec below

-record(state, {actions=[], calls, parent_mref, session_mref, call_waiters=[],
                mock_mfas=[], trace_mfas=[]}).
-record(call, {m, f, a}).
-record(action, {mfa, func}).
-record(call_waiter, {from, mfa, crit}).

%-record(trace, {msg}).
-record('DOWN', {mref, type, obj, info}).

%%%===================================================================
%%% API
%%%===================================================================

exec(MockMFAs, TraceMFAs, Fun) ->
    case start() of
        {ok, _} ->
            try
                case start_session(MockMFAs, TraceMFAs) of
                    ok ->
                        Fun();
                    {error, _} = Error ->
                        erlang:error(Error)
                end
            after
                stop()
            end;
        {error, {already_started, _}} ->
            erlang:error(nestling_mocks_is_not_allowed);
        {error, Reason} ->
            erlang:error({failed_to_mock, Reason})
    end.

get_action(MFA) ->
    call({get_action, MFA}).

set_action(MFA) ->
    call({set_action, MFA}).

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start() ->
    Parent = self(),
    gen_server:start({local, ?SERVER}, ?MODULE, {Parent}, []).

stop() ->
    call(stop).

start_session(MockMFAs, TraceMFAs) ->
    call({start_session, MockMFAs, TraceMFAs, self()}).

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
init({Parent}) ->
    MRef = erlang:monitor(process, Parent),
    {ok, #state{parent_mref=MRef}}.

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
handle_call({start_session, MockMFAs, TraceMFAs, Pid}, _From, State0) ->
    {Reply, State} = i_start_session(MockMFAs, TraceMFAs, Pid, State0),
    {reply, Reply, State};
handle_call({get_action, MFA}, _From, State) ->
    ActionFun = i_get_action(MFA, State),
    {reply, ActionFun, State};
handle_call({set_action, MFA}, _From, State0) ->
    State = i_set_action(MFA, State0),
    {reply, ok, State};
handle_call({verify, MFA, {was_called, Criteria}}, _From, State) ->
    Reply = get_and_check_matches(MFA, Criteria, State),
    {reply, Reply, State};
handle_call({verify, MFA, {wait_called, Criteria}}, From, State) ->
    case get_and_check_matches(MFA, Criteria, State) of
        {ok, _} = Reply ->
            {reply, Reply, State};
        {error, _} ->
            Waiters = State#state.call_waiters,
            Waiter  = #call_waiter{from=From, mfa=MFA, crit=Criteria},
            {noreply, State#state{call_waiters = [Waiter | Waiters]}}
    end;
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
handle_info(#'DOWN'{mref=MRef}, #state{parent_mref=MRef} = State) ->
    {stop, normal, State#state{parent_mref=undefined}};
handle_info(#'DOWN'{mref=MRef}, #state{session_mref=MRef} = State0) ->
    State = i_end_session(State0),
    {noreply, State};
handle_info({trace, _, call, MFA}, State0) ->
    State1 = i_reg_call(MFA, State0),
    State  = i_possibly_notify_waiters(State1),
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
    gen_server:call(?SERVER, Msg, infinity).

i_start_session(MockMFAs, TraceMFAs, Pid, State0) ->
    State = State0#state{mock_mfas=MockMFAs, trace_mfas=TraceMFAs},
    case mock_and_load_mods(get_unique_mods_by_mfas(MockMFAs)) of
        ok ->
            erlang:trace(all, true, [call, {tracer, self()}]),
            case setup_trace_on_all_mfas(TraceMFAs) of
                ok ->
                    MRef = erlang:monitor(process, Pid),
                    {ok, State#state{calls=[],
                                     session_mref=MRef}};
                {error, _}=Error ->
                    {Error, i_end_session(State)}
            end;
        {error, _} = Error ->
            {Error, State0}
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

i_end_session(#state{mock_mfas=MockMFAs} = State) ->
    unload_mods(get_unique_mods_by_mfas(MockMFAs)),
    erlang:trace(all, false, [call, {tracer, self()}]),
    State#state{session_mref=undefined, mock_mfas=[], trace_mfas=[]}.

i_reg_call({M, F, A}, #state{calls=Calls} = State) ->
    State#state{calls=[#call{m=M, f=F, a=A} | Calls]}.

i_possibly_notify_waiters(#state{call_waiters=Waiters0} = State) ->
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
    {error, {criteria_not_fulfilled, Criteria, N}}.


i_get_action(MFA, #state{actions=Actions}) ->
    case lists:keysearch(MFA, #action.mfa, Actions) of
        {value, #action{func=ActionFun}} -> ActionFun;
        false                            -> undefined
    end.

i_set_action({M, F, ActionFun}, #state{actions=Actions0} = State) ->
    {arity, A} = erlang:fun_info(ActionFun, arity),
    MFA = {M, F, A},
    Actions = lists:keystore(MFA, #action.mfa, Actions0,
                             #action{mfa=MFA, func=ActionFun}),
    State#state{actions=Actions}.

wait_until_trace_delivered() ->
    Ref = erlang:trace_delivered(all),
    receive {trace_delivered, _, Ref} -> ok end.

chk(ok)              -> ok;
chk({ok, Value})     -> Value;
chk({error, Reason}) -> erlang:error(Reason).

mock_and_load_mods(Mods) ->
    lists:foldl(fun(Mod, ok)     -> mock_and_load_mod(Mod);
                   (_Mod, Error) -> Error
                end,
                ok,
                Mods).

mock_and_load_mod(Mod) ->
    case get_exported_fas(Mod) of
        {ok, ExportedFAs} ->
            OrigMod = reload_mod_under_different_name(Mod),
            mk_mocking_mod(Mod, OrigMod, ExportedFAs),
            ok;
        {error, {no_such_module, Mod}} ->
            {error, {cant_mock_non_existing_module, Mod}}
    end.

reload_mod_under_different_name(Mod) ->
    {module, Mod} = code:ensure_loaded(Mod),
    {Mod, OrigBin0, Filename} = code:get_object_code(Mod),
    OrigMod = list_to_atom("^"++atom_to_list(Mod)),
    OrigBin = rename(OrigBin0, OrigMod),
    unload_mod(Mod),
    {module, OrigMod} = code:load_binary(OrigMod, Filename, OrigBin),
    OrigMod.

mk_mocking_mod(Mod, OrigMod, ExportedFAs) ->
    Forms0 = ([erl_syntax:attribute(erl_syntax:abstract(module),
                                    [erl_syntax:abstract(Mod)])]
              ++ mk_mocked_funcs(Mod, OrigMod, ExportedFAs)),
    Forms = [erl_syntax:revert(Form) || Form <- Forms0],
    {ok, Mod, Bin} = compile:forms(Forms, [report, export_all]),
    {module, Mod} = code:load_binary(Mod, "mock", Bin).

mk_mocked_funcs(Mod, OrigMod, ExportedFAs) ->
    lists:map(fun(ExportedFA) -> mk_mocked_func(Mod, OrigMod, ExportedFA) end,
              ExportedFAs).

mk_mocked_func(Mod, OrigMod, {F, A}) ->
    %% Generate a function like this (some_mod, some_func and arguments vary):
    %%
    %%     some_func(A2, A1) ->
    %%         case mockgyver:get_action({some_mod,some_func,2}) of
    %%             undefined ->
    %%                 '^some_mod':some_func(A2, A1);
    %%             ActionFun ->
    %%                 ActionFun(A2, A1)
    %%         end.
    Args = mk_args(A),
    Body =[erl_syntax:case_expr(
             mk_call(mockgyver, get_action,
                     [erl_syntax:tuple([erl_syntax:abstract(Mod),
                                        erl_syntax:abstract(F),
                                        erl_syntax:abstract(A)])]),
             [erl_syntax:clause([erl_syntax:atom(undefined)],
                                none,
                                [mk_call(OrigMod, F, Args)]),
              erl_syntax:clause([erl_syntax:variable('ActionFun')],
                                none,
                                [mk_call('ActionFun', Args)])])],
    erl_syntax:function(
      erl_syntax:abstract(F),
      [erl_syntax:clause(Args, none, Body)]).

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

get_exported_fas(Mod) ->
    try
        {ok, [FA || FA <- Mod:module_info(exports),
                    FA =/= {module_info, 0},
                    FA =/= {module_info, 1}]}
    catch
        error:undef ->
            {error, {no_such_module, Mod}}
    end.

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
