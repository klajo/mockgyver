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
%%% @private
%%% @doc Transform mock syntax into real function calls.
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
-record(m_init, {exec_fun}).
-record(m_when, {m, f, a, action}).
-record(m_verify, {m, f, a, g, crit}).

-record(env, {mock_mfas, trace_mfas}).

%%%===================================================================
%%% API
%%%===================================================================

parse_transform(Forms, Opts) ->
    parse_trans:top(fun parse_transform_2/2, Forms, Opts).

parse_transform_2(Forms0, Ctxt) ->
    Env = #env{mock_mfas  = find_mfas_to_mock(Forms0, Ctxt),
               trace_mfas = find_mfas_to_trace(Forms0, Ctxt)},
    {Forms1, _} = rewrite_init_stmts(Forms0, Ctxt, Env),
    {Forms2, _} = rewrite_when_stmts(Forms1, Ctxt),
    {Forms, _}  = rewrite_verify_stmts(Forms2, Ctxt),
    parse_trans:revert(Forms).

%%------------------------------------------------------------
%% init statements
%%------------------------------------------------------------
rewrite_init_stmts(Forms, Ctxt, Env) ->
    parse_trans:do_transform(fun rewrite_init_stmts_2/4, Env, Forms, Ctxt).

rewrite_init_stmts_2(Type, Form0, _Ctxt, Env) ->
    case is_mock_expr(Type, Form0) of
        {true, #m_init{exec_fun=ExecFun}} ->
            Befores = [],
            MockMfas = Env#env.mock_mfas,
            TraceMfas = Env#env.trace_mfas,
            [Form] = codegen:exprs(
                       fun() ->
                               mockgyver:exec({'$var',  MockMfas},
                                              {'$var',  TraceMfas},
                                              {'$form', ExecFun})
                       end),
            Afters = [],
            {Befores, Form, Afters, false, Env};
        _ ->
            {Form0, true, Env}
    end.

%%------------------------------------------------------------
%% when statements
%%------------------------------------------------------------
rewrite_when_stmts(Forms, Ctxt) ->
    parse_trans:do_transform(fun rewrite_when_stmts_2/4, x, Forms, Ctxt).

rewrite_when_stmts_2(Type, Form0, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form0) of
        {true, #m_when{m=M, f=F, action=ActionFun}} ->
            Befores = [],
            [Form] = codegen:exprs(
                       fun() ->
                               mockgyver:set_action({{'$var', M}, {'$var', F},
                                                     {'$form', ActionFun}})
                       end),
            Afters = [],
            {Befores, Form, Afters, false, Acc};
        _ ->
            {Form0, true, Acc}
    end.

find_mfas_to_mock(Forms, Ctxt) ->
    lists:usort(
      parse_trans:do_inspect(fun find_mfas_to_mock_f/4, [], Forms, Ctxt)).

find_mfas_to_mock_f(Type, Form, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form) of
        {true, #m_when{} = W} -> {false, [when_to_mfa(W) | Acc]};
        {true, _}             -> {true, Acc};
        false                 -> {true, Acc}
    end.

when_to_mfa(#m_when{m=M, f=F, a=A}) ->
    {M, F, A}.

%%------------------------------------------------------------
%% was called statements
%%------------------------------------------------------------
rewrite_verify_stmts(Forms, Ctxt) ->
    parse_trans:do_transform(fun rewrite_verify_stmts_2/4, x, Forms, Ctxt).

rewrite_verify_stmts_2(Type, Form0, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form0) of
        {true, #m_verify{m=M, f=F, a=A, g=G, crit=C}} ->
            Fun = mk_verify_checker_fun(A, G),
            Befores = [],
            [Form] = codegen:exprs(
                       fun() ->
                               mockgyver:verify(
                                 {{'$var', M}, {'$var', F}, {'$form', Fun}},
                                 {'$form', C})
                       end),
            Afters = [],
            {Befores, Form, Afters, false, Acc};
        _ ->
            {Form0, true, Acc}
    end.

find_mfas_to_trace(Forms, Ctxt) ->
    lists:usort(
      parse_trans:do_inspect(fun find_mfas_to_trace_f/4, [], Forms, Ctxt)).

find_mfas_to_trace_f(Type, Form, _Ctxt, Acc) ->
    case is_mock_expr(Type, Form) of
        {true, #m_verify{} = WC} -> {false, [verify_to_tpat(WC) | Acc]};
        {true, _}                -> {true, Acc};
        false                    -> {true, Acc}
    end.

verify_to_tpat(#m_verify{m=M, f=F, a=A}) ->
    {M, F, length(A)}. % a trace pattern we can pass to erlang:trace_pattern

%%------------------------------------------------------------
%% mock expression analysis
%%------------------------------------------------------------
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
        m_init   -> analyze_init_expr(Expr);
        m_when   -> analyze_when_expr(Expr);
        m_verify -> analyze_verify_expr(Expr)
    end.

analyze_init_expr(Expr) ->
    #m_init{exec_fun=Expr}.

analyze_when_expr(Expr) ->
    %% The sole purpose of the entire if expression is to let us write
    %%     ?WHEN(m:f(_) -> some_result).
    %% or
    %%     ?WHEN(m:f(1) -> some_result;).
    %%     ?WHEN(m:f(2) -> some_other_result).
    Clauses0 = erl_syntax:case_expr_clauses(Expr),
    {M, F, A} = ensure_all_clauses_implement_the_same_function(Clauses0),
    Clauses = lists:map(fun(Clause) ->
                                [Call | _] = erl_syntax:clause_patterns(Clause),
                                {_M, _F, Args} = analyze_application(Call),
                                Guard = erl_syntax:clause_guard(Clause),
                                Body  = erl_syntax:clause_body(Clause),
                                erl_syntax:clause(Args, Guard, Body)
                        end,
                        Clauses0),
    ActionFun = erl_syntax:fun_expr(Clauses),
    #m_when{m=M, f=F, a=A, action=ActionFun}.

ensure_all_clauses_implement_the_same_function(Clauses) ->
    lists:foldl(fun(Clause, undefined) ->
                        get_when_call_sig(Clause);
                   (Clause, {M, F, A}=MFA) ->
                        case get_when_call_sig(Clause) of
                            {M, F, A} ->
                                MFA;
                            OtherMFA ->
                                erlang:error({when_expr_function_mismatch,
                                              {expected, MFA},
                                              {got, OtherMFA}})
                        end
                end,
                undefined,
                Clauses).

get_when_call_sig(Clause) ->
    [Call | _] = erl_syntax:clause_patterns(Clause),
    {M, F, A} = analyze_application(Call),
    {M, F, length(A)}.

analyze_verify_expr(Form) ->
    [Case, Criteria] = erl_syntax:tuple_elements(Form),
    [Clause | _] = erl_syntax:case_expr_clauses(Case),
    [Call | _] = erl_syntax:clause_patterns(Clause),
    G = erl_syntax:clause_guard(Clause),
    {M, F, A} = analyze_application(Call),
    #m_verify{m=M, f=F, a=A, g=G, crit=erl_syntax:revert(Criteria)}.

mk_verify_checker_fun(Args0, Guard0) ->
    %% Let's say there's a statement like this:
    %%     N = 42,
    %%     ...
    %%     ?WAS_CALLED(x:y(N), once),
    %%
    %% How do we rewrite this to something that can be used to check
    %% whether it matches or not?
    %%
    %% * we want N to match only 42, but "fun(N) -> ... end" would
    %%   match anything
    %%
    %% * we could write a guard, but we'd need to take care of guards
    %%   the user has written and make sure our guards work with theirs
    %%
    %% * a match would take care of this
    %%
    %% Hence, convert the statement to a fun:
    %%     fun([____N]) ->
    %%            N = ____N,
    %%            [N]
    %%     end

    %% Rename all variables in the args list
    {Args1, NameMap0} = rename_vars(erl_syntax:list(Args0), fun(_) -> true end),
    Args = erl_syntax:list_elements(Args1),
    %% Rename only variables in guards which are also present in the args list
    RenameVars = [N0 || {N0, _N1} <- NameMap0],
    {Guard, _NameMap1} =
        rename_vars(Guard0, fun(V) -> lists:member(V, RenameVars) end),
    Body =
        %% This first statement generates one match expression per
        %% variable.  The idea is that a badmatch implies that the fun
        %% didn't match the call.
        [erl_syntax:match_expr(erl_syntax:variable(N0),
                               erl_syntax:variable(N1))
         || {N0, N1} <- NameMap0]
        %% This section ensures that all variables are used and we
        %% avoid the "unused variable" warning
        ++ [erl_syntax:list([erl_syntax:variable(N0) ||
                                {N0, _N1} <- NameMap0])],
    Clause = erl_syntax:clause(Args, Guard, Body),
    Clauses = parse_trans:revert([Clause]),
    erl_syntax:revert(erl_syntax:fun_expr(Clauses)).

rename_vars(none, _RenameP) ->
    {none, []};
rename_vars(Forms0, RenameP) ->
    {Forms, {NameMap, RenameP}} =
        erl_syntax_lib:mapfold(fun rename_vars_2/2, {[], RenameP}, Forms0),
    {Forms, lists:usort(NameMap)}.

rename_vars_2({var, L, VarName0}=Form, {NameMap0, RenameP}) ->
    case RenameP(VarName0) of
        true ->
            case atom_to_list(VarName0) of
                "_"++_ ->
                    {Form, {NameMap0, RenameP}};
                VarNameStr0 ->
                    VarName1 = list_to_atom("____" ++ VarNameStr0),
                    NameMap = [{VarName0, VarName1} | NameMap0],
                    {{var, L, VarName1}, {NameMap, RenameP}}
            end;
        false ->
            {Form, {NameMap0, RenameP}}
    end;
rename_vars_2(Form, {_NameMap, _RenameP}=Acc) ->
    {Form, Acc}.

analyze_application(Form) ->
    MF = erl_syntax:application_operator(Form),
    M  = erl_syntax:concrete(erl_syntax:module_qualifier_argument(MF)),
    F  = erl_syntax:concrete(erl_syntax:module_qualifier_body(MF)),
    A  = erl_syntax:application_arguments(Form),
    {M, F, A}.
