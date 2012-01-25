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

-compile(export_all).

-record('DOWN', {mref, type, obj, info}).

mock_test_() ->
    code:add_patha(filename:dirname(code:which(?MODULE))),
    ?WITH_MOCKED_SETUP(fun setup/0, fun cleanup/1).

setup() ->
    ok.

cleanup(_) ->
    ok.

only_allows_one_mock_at_a_time_test() ->
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
    mockgyver_dummy:return_arg(1),
    mockgyver_dummy:return_arg({N,O}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(N), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg(O), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg({_,N}), never),
    ?WAS_CALLED(mockgyver_dummy:return_arg({N,O}), once).

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

can_call_original_module_test(_) ->
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
