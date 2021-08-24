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

-module(mockgyver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("../include/mockgyver.hrl").

%% This macro was introduced in Erlang/OTP 19.0.
%% This is a workaround for older releases.
-ifndef(FUNCTION_NAME).
-define(FUNCTION_NAME,
        element(2, element(2, process_info(self(), current_function)))).
-endif.

-record('DOWN', {mref, type, obj, info}).

-define(recv(PatternAction), ?recv(PatternAction, 4000)).
-define(recv(PatternAction, Timeout),
        fun() ->
                receive PatternAction
                after Timeout ->
                        error({failed_to_receive, ??PatternAction,
                               process_info(self(), messages)})
                end
        end()).


mock_test_() ->
    code:add_patha(test_dir()),
    ?WITH_MOCKED_SETUP(fun setup/0, fun cleanup/1).

setup() ->
    ok.

cleanup(_) ->
    ok.

only_allows_one_mock_at_a_time_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun only_allows_one_mock_at_a_time_test_aux/0}.

only_allows_one_mock_at_a_time_test_aux() ->
    NumMockers = 10,
    Parent = self(),
    Mocker = fun() ->
                     ?MOCK(fun() ->
                                   Parent ! {mock_start, self()},
                                   timer:sleep(5),
                                   Parent ! {mock_end, self()}
                           end)
        end,
    Mockers = [proc_lib:spawn(Mocker) || _ <- lists:seq(1, NumMockers)],
    wait_until_mockers_terminate(Mockers),
    Msgs = fetch_n_msgs(NumMockers*2),
    check_no_simultaneous_mockers_outside(Msgs).

wait_until_mockers_terminate([Pid | Pids]) ->
    MRef = erlang:monitor(process, Pid),
    receive
        #'DOWN'{mref=MRef, info=Info} when Info==normal; Info==noproc ->
            wait_until_mockers_terminate(Pids);
        #'DOWN'{mref=MRef, info=Info} ->
            erlang:error({mocker_terminated_abnormally, Pid, Info})
    end;
wait_until_mockers_terminate([]) ->
    ok.

fetch_n_msgs(0) -> [];
fetch_n_msgs(N) -> [receive M -> M end | fetch_n_msgs(N-1)].

check_no_simultaneous_mockers_outside([{mock_start, Pid} | Msgs]) ->
    check_no_simultaneous_mockers_inside(Msgs, Pid);
check_no_simultaneous_mockers_outside([]) ->
    ok.

check_no_simultaneous_mockers_inside([{mock_end, Pid} | Msgs], Pid) ->
    check_no_simultaneous_mockers_outside(Msgs).

can_test_again_after_session_dies_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun can_test_again_after_session_dies_aux/0}.

can_test_again_after_session_dies_aux() ->
    P1 = proc_lib:spawn(fun() -> ?MOCK(fun() -> crash_me_via_process_link() end)
                        end),
    M1 = monitor(process, P1),
    ?recv(#'DOWN'{mref=M1} -> ok),
    ?MOCK(fun() -> ok end),
    ok.

crash_me_via_process_link() ->
    spawn_link(fun() -> exit(shutdown) end),
    timer:sleep(infinity).

traces_single_arg_test(_) ->
    1 = mockgyver_dummy:return_arg(1),
    2 = mockgyver_dummy:return_arg(2),
    2 = mockgyver_dummy:return_arg(2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(2), {times, 2}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 3}).

traces_multi_args_test(_) ->
    {a, 1} = mockgyver_dummy:return_arg(a, 1),
    {a, 2} = mockgyver_dummy:return_arg(a, 2),
    {b, 2} = mockgyver_dummy:return_arg(b, 2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(b, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 1), {times, 1}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 2), {times, 2}).

traces_in_separate_process_test(_) ->
    Pid = proc_lib:spawn_link(fun() -> mockgyver_dummy:return_arg(1) end),
    MRef = erlang:monitor(process, Pid),
    receive {'DOWN',MRef,_,_,_} -> ok end,
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), once).

was_called_defaults_to_once_test(_) ->
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_)),
    mockgyver_dummy:return_arg(1),
    ?assertError(_, ?WAS_CALLED(mockgyver_dummy:return_arg(_))).

matches_called_arguments_test(_) ->
    N = 42,
    O = 1,
    P = 4711,
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg({N, O}),
    mockgyver_dummy:return_arg(P, P),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(O), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg({_, N}), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg({N, O}), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(P, P), once).

allows_was_called_guards_test(_) ->
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N) when N == 1, once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N) when N == 2, never).

allows_was_called_guards_with_variables_not_used_in_args_list_test(_) ->
    W = 2,
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_) when W == 2, once).

returns_called_arguments_test(_) ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg(2),
    [[1], [2]] = ?WAS_CALLED(mockgyver_dummy:return_arg(N), {times, 2}).

allows_variables_in_criteria_test(_) ->
    C = {times, 0},
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), C).

returns_error_on_invalid_criteria_test(_) ->
    lists:foreach(
      fun(C) ->
              ?assertError({{reason, {invalid_criteria, C}},
                            {location, _}},
                           ?WAS_CALLED(mockgyver_dummy:return_arg(_), C))
      end,
      [0,
       x,
       {at_least, x},
       {at_most, x},
       {times, x}]).

checks_that_two_different_functions_are_called_test(_) ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg2(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg2(1), once).

knows_the_difference_in_arities_test(_) ->
    mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), never).

can_verify_both_mocked_and_non_mocked_modules_test(_) ->
    ?WHEN(mockgyver_dummy:return_arg(_) -> [3, 2, 1]),
    [3, 2, 1] = lists:reverse([1, 2, 3]),
    [3, 2, 1] = mockgyver_dummy:return_arg(1),
    ?WAS_CALLED(lists:reverse(_)),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_)).

handles_all_criterias_test(_) ->
    %% never
    {error, {fewer_calls_than_expected, _, _}} =
         mockgyver:check_criteria(never, -1),
    ok = mockgyver:check_criteria(never, 0),
    {error, {more_calls_than_expected, _, _}} =
         mockgyver:check_criteria(never, 1),
    %% once
    {error, {fewer_calls_than_expected, _, _}} =
         mockgyver:check_criteria(once, 0),
    ok = mockgyver:check_criteria(once, 1),
    {error, {more_calls_than_expected, _, _}} =
        mockgyver:check_criteria(once, 2),
    %% at_least
    {error, {fewer_calls_than_expected, _, _}} =
         mockgyver:check_criteria({at_least, 0}, -1),
    ok = mockgyver:check_criteria({at_least, 0}, 0),
    ok = mockgyver:check_criteria({at_least, 0}, 1),
    %% at_most
    ok = mockgyver:check_criteria({at_most, 0}, -1),
    ok = mockgyver:check_criteria({at_most, 0}, 0),
    {error, {more_calls_than_expected, _, _}} =
         mockgyver:check_criteria({at_most, 0}, 1),
    %% times
    {error, {fewer_calls_than_expected, _, _}} =
         mockgyver:check_criteria({times, 0}, -1),
    ok = mockgyver:check_criteria({times, 0}, 0),
    {error, {more_calls_than_expected, _, _}} =
         mockgyver:check_criteria({times, 0}, 1),
    ok.

returns_immediately_if_waiters_criteria_already_fulfilled_test(_) ->
    mockgyver_dummy:return_arg(1),
    ?WAIT_CALLED(mockgyver_dummy:return_arg(N), once).

waits_until_waiters_criteria_fulfilled_test(_) ->
    spawn(fun() -> timer:sleep(50), mockgyver_dummy:return_arg(1) end),
    ?WAIT_CALLED(mockgyver_dummy:return_arg(N), once).

fails_directly_if_waiters_criteria_already_surpassed_test(_) ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg(1),
    ?assertError(_, ?WAIT_CALLED(mockgyver_dummy:return_arg(N), once)).

returns_other_value_test(_) ->
    1  = mockgyver_dummy:return_arg(1),
    2  = mockgyver_dummy:return_arg(2),
    ?WHEN(mockgyver_dummy:return_arg(1) -> 42),
    42 = mockgyver_dummy:return_arg(1),
    ?assertError(function_clause, mockgyver_dummy:return_arg(2)).

can_change_return_value_test(_) ->
    1  = mockgyver_dummy:return_arg(1),
    ?WHEN(mockgyver_dummy:return_arg(1) -> 42),
    42 = mockgyver_dummy:return_arg(1),
    ?assertError(function_clause, mockgyver_dummy:return_arg(2)),
    ?WHEN(mockgyver_dummy:return_arg(_) -> 43),
    43 = mockgyver_dummy:return_arg(1),
    43 = mockgyver_dummy:return_arg(2).

inherits_variables_from_outer_scope_test(_) ->
    NewVal = 42,
    ?WHEN(mockgyver_dummy:return_arg(_) -> NewVal),
    42 = mockgyver_dummy:return_arg(1).

can_use_params_test(_) ->
    ?WHEN(mockgyver_dummy:return_arg(N) -> N+1),
    2 = mockgyver_dummy:return_arg(1).

can_use_multi_clause_functions_test(_) ->
    ?WHEN(mockgyver_dummy:return_arg(N) when N >= 0 -> positive;
          mockgyver_dummy:return_arg(_N)            -> negative),
    positive = mockgyver_dummy:return_arg(1),
    negative = mockgyver_dummy:return_arg(-1).

fails_gracefully_when_mocking_a_bif_test(_) ->
    %% previously the test checked that pi/0 could be successfully
    %% mocked here -- it's a non-bif function -- but starting at
    %% Erlang/OTP R15B this is marked as a pure function which means that
    %% the compiler will inline it into the testcase so we cannot mock it.
    %%
    %% cos/1 should work (uses the bif)
    1.0 = math:cos(0),
    %% mocking the bif should fail gracefully
    ?assertError({cannot_mock_bif, {math, cos, 1}}, ?WHEN(math:cos(_) -> 0)).

can_call_renamed_module_test(_) ->
    ?WHEN(mockgyver_dummy:return_arg(N) -> 2*'mockgyver_dummy^':return_arg(N)),
    6 = mockgyver_dummy:return_arg(3).

can_make_new_module_test(_) ->
    ?WHEN(mockgyver_extra_dummy:return_arg(N) -> N),
    ?WHEN(mockgyver_extra_dummy:return_arg(M, N) -> {M, N}),
    1 = mockgyver_extra_dummy:return_arg(1),
    {1, 2} = mockgyver_extra_dummy:return_arg(1, 2).

can_make_new_function_in_existing_module_test(_) ->
    ?WHEN(mockgyver_dummy:inc_arg_by_two(N) -> 2*N),
    1 = mockgyver_dummy:return_arg(1),
    2 = mockgyver_dummy:inc_arg_by_two(1).

counts_calls_test(_) ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg(2),
    mockgyver_dummy:return_arg(2),
    0 = ?NUM_CALLS(mockgyver_dummy:return_arg(_, _)),
    1 = ?NUM_CALLS(mockgyver_dummy:return_arg(1)),
    2 = ?NUM_CALLS(mockgyver_dummy:return_arg(2)),
    3 = ?NUM_CALLS(mockgyver_dummy:return_arg(_)).

returns_calls_test(_) ->
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg(2),
    mockgyver_dummy:return_arg(2),
    [] = ?GET_CALLS(mockgyver_dummy:return_arg(_, _)),
    [[1]] =
        ?GET_CALLS(mockgyver_dummy:return_arg(1)),
    [[2], [2]] =
        ?GET_CALLS(mockgyver_dummy:return_arg(2)),
    [[1], [2], [2]] =
        ?GET_CALLS(mockgyver_dummy:return_arg(_)).

forgets_when_to_default_test(_) ->
    1      = mockgyver_dummy:return_arg(1),
    {1, 2} = mockgyver_dummy:return_arg(1, 2),
    ?WHEN(mockgyver_dummy:return_arg(_) -> foo),
    ?WHEN(mockgyver_dummy:return_arg(_, _) -> foo),
    foo = mockgyver_dummy:return_arg(1),
    foo = mockgyver_dummy:return_arg(1, 2),
    ?FORGET_WHEN(mockgyver_dummy:return_arg(_)),
    1   = mockgyver_dummy:return_arg(1),
    foo = mockgyver_dummy:return_arg(1, 2).

forgets_registered_calls_test(_) ->
    1      = mockgyver_dummy:return_arg(1),
    2      = mockgyver_dummy:return_arg(2),
    3      = mockgyver_dummy:return_arg(3),
    {1, 2} = mockgyver_dummy:return_arg(1, 2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 3}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), once),
    ?FORGET_CALLS(mockgyver_dummy:return_arg(1)),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 2}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), once),
    ?FORGET_CALLS(mockgyver_dummy:return_arg(_)),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), once),
    ?FORGET_CALLS(mockgyver_dummy:return_arg(_, _)),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), never).

forgets_all_calls_test(_) ->
    1      = mockgyver_dummy:return_arg(1),
    2      = mockgyver_dummy:return_arg(2),
    3      = mockgyver_dummy:return_arg(3),
    {1, 2} = mockgyver_dummy:return_arg(1, 2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 3}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), once),
    ?FORGET_CALLS(),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, _), never).

returns_error_on_trying_to_mock_or_check_criteria_when_not_mocking_test() ->
    %% Note: This function has intentionally no parameter, to make
    %%       eunit pick it up and avoid starting the mocking
    %%       framework.  Check that this returns a nice and
    %%       understandable error message.
    %%
    %%       These are calls that will be made from a test case.
    ?assertError(mocking_not_started,
                 ?WHEN(mockgyver_dummy:return_arg(_) -> foo)),
    ?assertError(mocking_not_started,
                 ?WAS_CALLED(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?WAIT_CALLED(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?NUM_CALLS(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?GET_CALLS(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?FORGET_WHEN(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?FORGET_CALLS(mockgyver_dummy:return_arg(_))),
    ?assertError(mocking_not_started,
                 ?FORGET_CALLS()),
    ok.

returns_error_on_trying_to_get_mock_info_when_not_mocking_test() ->
    %% Note: This function has intentionally no parameter, to make
    %%       eunit pick it up and avoid starting the mocking
    %%       framework.  Check that this returns a nice and
    %%       understandable error message.
    %%
    %%       These are calls that will be made from within a mock,
    %%       i.e. calls are mackgyver-internal and will not be seen in
    %%       test cases.
    ?assertError(mocking_not_started,
                 mockgyver:get_action({mockgyver_dummy, return_arg, [1]})),
    ?assertError(mocking_not_started,
                 mockgyver:reg_call_and_get_action({mockgyver_dummy, return_arg, [1]})).

%% Ensure that trace on lists:reverse has been enabled at least once
%% so we can test that it has been removed in
%% 'removes_trace_pattern_test'.
activates_trace_on_lists_reverse_test(_) ->
    [] = lists:reverse([]),
    ?WAS_CALLED(lists:reverse(_)).

%% Trace is removed after the mockgyver session has finished, so we
%% cannot test it in a mockgyver test case (arity 1).
removes_trace_pattern_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun removes_trace_pattern_test_aux/0}.

removes_trace_pattern_test_aux() ->
    {flags, Flags} = erlang:trace_info(new, flags),
    erlang:trace(all, false, Flags),
    erlang:trace(all, true, [call, {tracer, self()}]),

    Master = self(),
    Ref = make_ref(),
    %% spawn as trace is not activated on the tracing process
    spawn(fun() ->
		  lists:reverse([]),
		  Master ! {Ref, done}
	  end),
    
    receive {Ref, done} -> ok end,
    TRef = erlang:trace_delivered(self()),
    receive {trace_delivered, _, TRef} -> ok end,

    ?assertEqual([], flush()).

%% A cached mocking module shall not be used if the original module
%% has been changed.
changed_module_is_used_instead_of_cached_test_() ->
    {timeout, ?PER_TC_TIMEOUT,
     fun changed_module_is_used_instead_of_cached_test_aux/0}.

changed_module_is_used_instead_of_cached_test_aux() ->
    create_dummy(mockgyver_dummy2, a),
    ?MOCK(fun() ->
                  %% fool mockgyver into mocking the module by mocking
                  %% a function that we will _not_ use within that
                  %% module
                  ?WHEN(mockgyver_dummy2:c() -> ok),
                  1 = mockgyver_dummy2:a(1),
                  ?assertError(undef, mockgyver_dummy2:b(1))
          end),
    create_dummy(mockgyver_dummy2, b),
    ?MOCK(fun() ->
                  %% fool mockgyver into mocking the module by mocking
                  %% a function that we will _not_ use within that
                  %% module
                  ?WHEN(mockgyver_dummy2:c() -> ok),
                  ?assertError(undef, mockgyver_dummy2:a(1)),
                  1 = mockgyver_dummy2:b(1)
          end).

can_mock_a_dynamically_generated_module_test_() ->
    %% Check that it is possible to mock a module that is loaded into
    %% the vm, but does not exist on disk, such as a dynamically
    %% generated module.
    RText = lists:flatten(io_lib:format("~p", [make_ref()])),
    ok = compile_load_txt_forms(
           mockgyver_dyn_ref_text,
           ["-module(mockgyver_dyn_ref_text).\n",
            "-export([ref_text/0]).\n",
            "ref_text() -> \"" ++ RText ++ "\".\n"]),
    RText = mockgyver_dyn_ref_text:ref_text(),
    {timeout, ?PER_TC_TIMEOUT,
     fun() -> can_mock_a_dynamically_generated_module_test_aux(RText) end}.

can_mock_a_dynamically_generated_module_test_aux(_OrigRText) ->
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dyn_ref_text:ref_text() -> "a"),
                  ?assertEqual("a", mockgyver_dyn_ref_text:ref_text())
          end).

can_mock_a_module_with_on_load_test_() ->
    {timeout, ?PER_TC_TIMEOUT,
     fun can_mock_a_module_with_on_load_aux/0}.

can_mock_a_module_with_on_load_aux() ->
    %% The code:atomic_load/1 does not allow modules with -on_load().
    %% The mockgyver falls back to loading such modules individually.
    %% Test that.
    Dir = test_dir(),
    Mod = mockgyver_dummy3,
    Filename = filename:join(Dir, atom_to_list(Mod) ++ ".erl"),
    ok = file:write_file(Filename,
                         io_lib:format("%% Generated by ~p:~p~n"
                                       "-module(~p).~n"
                                       "-export([z/1]).~n"
                                       "-on_load(do_nothing/0).~n"
                                       "z(Z) -> Z.~n"
                                       "do_nothing() -> ok.~n",
                                       [?MODULE, ?FUNCTION_NAME, Mod])),
    {ok, Mod} = compile:file(Filename, [{outdir, Dir}]),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy3:x() -> mocked),
                  ?WHEN(mockgyver_dummy3:y() -> also_mocked),
                  mocked = mockgyver_dummy3:x(),
                  abc123 = mockgyver_dummy3:z(abc123)
          end).

mock_sequence_of_just_1_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun mock_sequence_of_just_1_aux/0}.

mock_sequence_of_just_1_aux() ->
    create_dummy(mockgyver_dummy4, a),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy4:a(_) -> mocked),
                  mocked = mockgyver_dummy4:a(1)
          end,
          [{mock_sequence, #{num_sessions => 1, index => 1,
                             signature => {?FUNCTION_NAME, ?LINE}}}]),
    %% mocking should be unloaded after the one mock in the sequence
    ?assertEqual(not_mocked, mockgyver_dummy4:a(not_mocked)).

two_mock_sequences_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun two_mock_sequences_aux/0}.

two_mock_sequences_aux() ->
    %% This imitates two ?WITH_MOCKED_SETUP after each other.
    create_dummy(mockgyver_dummy5, a),
    create_dummy(mockgyver_dummy6, a),
    UnmockedChecksum5 = mockgyver_dummy5:module_info(md5),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy5:a(_) -> mocked_1_1),
                  mocked_1_1 = mockgyver_dummy5:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 1, signature => a}}]),
    %% It should stay mocked across sessions in a mock_sequence,
    %% that's the optimizaion. Can't call it to  test it though---that
    %% would require a session---so test it in another way.
    ?assertNotEqual(UnmockedChecksum5, mockgyver_dummy5:module_info(md5)),
    ?MOCK(fun() ->
                  %% The ?WHEN from previous ?MOCK in the mock sueqence
                  %% should not initially be active:
                  1 = mockgyver_dummy5:a(1),
                  %% But it should still be possible to mock it again:
                  ?WHEN(mockgyver_dummy5:a(_) -> mocked_1_2),
                  mocked_1_2 = mockgyver_dummy5:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 2, signature => a}}]),
    %% It should get restored after the last session in the sequence
    ?assertEqual(UnmockedChecksum5, mockgyver_dummy5:module_info(md5)),
    1 = mockgyver_dummy5:a(1),
    %% Next sequence:
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy6:a(_) -> mocked_2_1),
                  not_mocked = mockgyver_dummy5:a(not_mocked),
                  mocked_2_1 = mockgyver_dummy6:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 1, signature => b}}]),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy6:a(_) -> mocked_2_2),
                  not_mocked = mockgyver_dummy5:a(not_mocked),
                  mocked_2_2 = mockgyver_dummy6:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 2, signature => b}}]),
    ok.

timeout_in_mock_sequence_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun timeout_in_mock_sequence_aux/0}.

timeout_in_mock_sequence_aux() ->
    {ok, _} = application:ensure_all_started(mockgyver),
    with_tmp_app_env(mock_sequence_timeout, 1,
                     fun timeout_in_mock_sequence_aux2/0).

timeout_in_mock_sequence_aux2() ->
    create_dummy(mockgyver_dummy7, a),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy7:a(_) -> mocked),
                  mocked = mockgyver_dummy7:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 1,
                             signature => {?FUNCTION_NAME, ?LINE}}}]),
    ok = await_state(no_session, 1000),
    %% the mocking should be unloaded after the timeout
    ?assertEqual(not_mocked, mockgyver_dummy7:a(not_mocked)).

signature_changes_mid_mock_sequence_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun signature_changes_mid_mock_sequence_aux/0}.

signature_changes_mid_mock_sequence_aux() ->
    %% This imitates a ?WITH_MOCKED_SETUP that gets interrupted,
    %% then another ?WITH_MOCKED_SETUP starts.
    create_dummy(mockgyver_dummy8, a),
    create_dummy(mockgyver_dummy9, a),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy8:a(_) -> mocked),
                  mocked = mockgyver_dummy8:a(1)
          end,
          [{mock_sequence, #{num_sessions => 3, index => 1, signature => x}}]),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy8:a(_) -> mocked),
                  mocked = mockgyver_dummy8:a(1)
          end,
          [{mock_sequence, #{num_sessions => 3, index => 2, signature => x}}]),
    %% now the sequence gets interrupted, a new sequence signature:
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummy9:a(_) -> mocked),
                  %% The x-signature's mocking should be unload by now:
                  no_longer_mocked = mockgyver_dummy8:a(no_longer_mocked),
                  mocked           = mockgyver_dummy9:a(1)
          end,
          [{mock_sequence, #{num_sessions => 1, index => 1, signature => y}}]),
    ok.

no_mock_sequence_opt_test_() ->
    {timeout, ?PER_TC_TIMEOUT, fun no_mock_sequence_opt_aux/0}.

no_mock_sequence_opt_aux() ->
    create_dummy(mockgyver_dummya, a),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummya:a(A) -> A + 1),
                  2 = mockgyver_dummya:a(1)
          end,
          [no_mock_sequence,
           {mock_sequence, #{num_sessions => 2, index => 1, signature => w}}]),
    %% It should not be mocked between sessions due to no_mock_sequence
    1 = mockgyver_dummya:a(1),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummya:a(A) -> A + 1),
                  2 = mockgyver_dummya:a(1)
          end,
          [no_mock_sequence,
           {mock_sequence, #{num_sessions => 2, index => 2, signature => w}}]).

renamed_gets_called_when_mocked_mod_called_between_sessions_test_() ->
    {timeout, ?PER_TC_TIMEOUT,
     fun renamed_gets_called_when_mocked_mod_called_between_sessions_aux/0}.

renamed_gets_called_when_mocked_mod_called_between_sessions_aux() ->
    with_tmp_app_env(
      mock_sequence_timeout, ?PER_TC_TIMEOUT * 1000,
      fun renamed_gets_called_when_mocked_mod_called_between_sessions_aux2/0).

renamed_gets_called_when_mocked_mod_called_between_sessions_aux2() ->
    create_dummy(mockgyver_dummyb, a),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummyb:a(_) -> 11),
                  11 = mockgyver_dummyb:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 1, signature => b}}]),
    %% Calls to functions in mocked modules should go to the renamed module^
    %% between sessions
    1 = mockgyver_dummyb:a(1),
    ?MOCK(fun() ->
                  ?WHEN(mockgyver_dummyb:a(_) -> 12),
                  12 = mockgyver_dummyb:a(1)
          end,
          [{mock_sequence, #{num_sessions => 2, index => 2, signature => b}}]),
    ok.

await_state(StateName, N) ->
    case sys:get_state(mockgyver) of
        {StateName, _StateData} ->
            ok;
        _Other when N >= 1 ->
            timer:sleep(5),
            await_state(StateName, N - 1);
        Other when N == 0 ->
            {timeout_waiting_for_state, StateName, Other}
    end.

with_tmp_app_env(Var, Val, F) ->
    Orig = application:get_env(mockgyver, Var),
    application:set_env(mockgyver, Var, Val),
    try F()
    after
        %% Make sure the temporary timeout is restored:
        case Orig of
            undefined     -> application:unset_env(mockgyver, Var);
            {ok, OrigVal} -> application:set_env(mockgyver, Var, OrigVal)
        end
    end.

create_dummy(Mod, Func) ->
    Dir = test_dir(),
    Filename = filename:join(Dir, atom_to_list(Mod) ++ ".erl"),
    file:write_file(Filename,
                    io_lib:format("%% Generated by ~p:~p~n"
                                  "-module(~p).~n"
                                  "-export([~p/1]).~n"
                                  "~p(X) -> X.",
                                  [?MODULE, ?FUNCTION_NAME, Mod,
                                   Func, Func])),
    {ok, Mod} = compile:file(Filename, [{outdir, Dir}]).

compile_load_txt_forms(Mod, TextForms) ->
    Forms = [begin
                 {ok, Tokens, _} = erl_scan:string(Text),
                 {ok, F} = erl_parse:parse_form(Tokens),
                 F
             end
             || Text <- TextForms],
    {ok, Mod, Bin, []} = compile:noenv_forms(Forms, [binary, return]),
    {module, Mod} = code:load_binary(Mod, "dyn", Bin),
    ok.

flush() ->
    receive Msg ->
	    [Msg | flush()]
    after 0 ->
	    []
    end.

test_dir() ->
    filename:dirname(code:which(?MODULE)).
