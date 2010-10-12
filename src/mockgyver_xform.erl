%%%-------------------------------------------------------------------
%%% @author Klas Johansson klas.johansson@gmail.com
%%% @copyright (C) 2010, Klas Johansson
%%% @doc
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver_xform).

%% This might be confusing, but this module (which is a parse
%% transform) is actually itself parse transformed by a 3pp library
%% (http://github.com/esl/parse_trans).  This transform makes it
%% easier for this module to generate code within the modules it
%% transforms.  Simple, eh? :-)
-compile({parse_transform, parse_trans_codegen}).

%% API
-export([parse_transform/2]).

%% Records
-record(m_when, {m, f, a, action}).
-record(m_was_called, {m, f, a, crit}).

%%%===================================================================
%%% API
%%%===================================================================

parse_transform(Forms, Opts) ->
    %% io:format(user, "==> ~p~n", [find_mfas_to_trace(Forms0, Opts)]),
    %% {Forms1, _} = parse_trans:depth_first(fun inject_init_f/4, x, Forms0, Opts),
    %% a = rewrite_was_called_stmts(Forms1, Opts),
    %% Forms = Forms1,
    %% io:format(user, "==> ~p~n", [Forms]),
    %% parse_trans:revert(Forms).
    parse_trans:top(fun parse_transform_2/2, Forms, Opts).

parse_transform_2(Forms0, Ctxt) ->
    MFAs = find_mfas_to_trace(Forms0, Ctxt),
    io:format(user, "==> ~p~n", [MFAs]),
    {Forms, _} = rewrite_was_called_stmts(Forms0, Ctxt),
    parse_trans:revert(Forms).
    
inject_init_f(function, Form, _Ctxt, Acc) ->
    Name = erl_syntax:function_name(Form),
    Cs0  = erl_syntax:function_clauses(Form),
    Cs = Cs0,
    {erl_syntax:function(Name, Cs), Acc};
inject_init_f(_Type, Form, _Ctxt, Acc) ->
    {Form, Acc}.

rewrite_was_called_stmts(Forms, Ctxt) ->
    parse_trans:do_transform(fun rewrite_was_called_stmts_2/4, x, Forms, Ctxt).

rewrite_was_called_stmts_2(Type, Form0, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form0) of
        {true, #m_was_called{m=M, f=F, a=A0, crit=C}} ->
            A = args_to_match_spec(A0),
            Befores = codegen:exprs(fun() -> fixme1 end),
            Afters = [],
            [Form] = codegen:exprs(
                       fun() ->
                               mockgyver:was_called({{'$var',M}, {'$var',F}, {'$var',A}}, {'$var',C})
                       end),
            io:format(user, "==> ~p~n", [Form]),
            {Befores, Form, Afters, false, Acc};
        _ ->
            {Form0, true, Acc}
    end.

find_mfas_to_trace(Forms, Ctxt) ->
    lists:usort(
      parse_trans:do_inspect(fun find_mfas_to_trace_f/4, [], Forms, Ctxt)).
%%    parse_trans:inspect(fun find_mfas_to_trace_f/4, [], Forms, Opts).

find_mfas_to_trace_f(Type, Form, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form) of
        {true, #m_was_called{} = WC} -> {false, [was_called_to_tpat(WC) | Acc]};
        {true, _}                    -> {false, Acc};
        false                        -> {true, Acc}
    end.

was_called_to_tpat(#m_was_called{m=M, f=F, a=A}) ->
    {M, F, length(A)}. % a trace pattern we can pass to erlang:trace_pattern

is_mock_expr(tuple, Form) ->
    case erl_syntax:tuple_elements(Form) of
        [H | T] ->
            case erl_syntax:is_atom(H, '$mock') of
                true  -> {true, analyze_mock_form(T)};
                false -> false
            end;
        _Other ->
            false
    end;
is_mock_expr(_Type, _Form) ->
    false.

analyze_mock_form([Type, Expr]) ->
    case erl_syntax:atom_value(Type) of
        m_when       -> analyze_when_expr(Expr);
        m_was_called -> analyze_was_called_expr(Expr)
    end.

analyze_when_expr(Expr) ->
    %% The first clause of the if expression is all we want, the sole
    %% purpose of the entire if expression is to let us write
    %% ?WHEN(m:f(A) -> some_result).
    [Clause | _] = erl_syntax:if_expr_clauses(Expr),
    Disj = erl_syntax:clause_guard(Clause),
    [Conj] = erl_syntax:disjunction_body(Disj),
    [Call] = erl_syntax:conjunction_body(Conj),
    {M, F, A} = analyze_application(Call),
    Result = erl_syntax:clause_body(Clause),
    #m_when{m=M, f=F, a=A, action=Result}.

analyze_was_called_expr(Form) ->
    [Call, Criteria] = erl_syntax:tuple_elements(Form),
    {M, F, A} = analyze_application(Call),
    #m_was_called{m=M, f=F, a=A, crit=erl_syntax:concrete(Criteria)}.

args_to_match_spec(Args) ->
    %% The idea here is that we'll use the match spec transform from
    %% the shell.  Example:
    %%
    %%     1> dbg:fun2ms(fun([1]) -> ok end)
    %%     [{[1,2],[],[ok]}]
    %%
    %% The shell does this by taking the parsed clauses from the fun:
    %%
    %%     [{clause,1,
    %%      [{cons,1,
    %%        {integer,1,1},
    %%        {cons,1,{integer,1,2},{nil,1}}}],
    %%      [],
    %%      [{atom,1,ok}]}]
    %%
    %% ... and passing it to:
    %%
    %%     ms_transform:transform_from_shell(dbg, Expr)
    Clause = erl_syntax:clause(_Pat=[erl_syntax:abstract(Args)],
                               _Guard=none,
                               _Body=[erl_syntax:atom(dummy)]),
    Clauses = parse_trans:revert([Clause]),
    ms_transform:transform_from_shell(dbg, Clauses, []).

analyze_application(Form) ->
    MF = erl_syntax:application_operator(Form),
    A  = [erl_syntax:concrete(X) ||
             X <- erl_syntax:application_arguments(Form)],
    M  = erl_syntax:concrete(erl_syntax:module_qualifier_argument(MF)),
    F  = erl_syntax:concrete(erl_syntax:module_qualifier_body(MF)),
    {M, F, A}.
