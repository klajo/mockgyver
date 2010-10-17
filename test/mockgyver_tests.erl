-module(mockgyver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("../include/mockgyver.hrl").

-compile(export_all).

%% was_called_test() ->
%%     mockgyver:start_link(),
%%     mockgyver:start_session([{x, test, 1}]),
%%     x:test(1),
%%     x:test(2),
%%     proc_lib:spawn(fun() -> x:test(2) end),
%% %    timer:sleep(100),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([1]) -> ok end)}, once),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {times, 2}),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {at_least, 2}),
%%     ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([3]) -> ok end)}, never).

mock_test_() ->
    Ts = [fun traces_single_arg/0,
          fun traces_multi_args/0,
          fun traces_in_separate_process/0],
    [fun() -> ?MOCK(T) end || T <- Ts].

traces_single_arg() ->
    %%    ?WHEN(x:test(1) -> 42),
    1 = mockgyver_dummy:return_arg(1),
    2 = mockgyver_dummy:return_arg(2),
    2 = mockgyver_dummy:return_arg(2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(2), {times, 2}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), {times, 3}).

traces_multi_args() ->
    %%    ?WHEN(x:test(1) -> 42),
    {a, 1} = mockgyver_dummy:return_arg(a, 1),
    {a, 2} = mockgyver_dummy:return_arg(a, 2),
    {b, 2} = mockgyver_dummy:return_arg(b, 2),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 1), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(a, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(b, 2), once),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 1), {times, 1}),
    ?WAS_CALLED(mockgyver_dummy:return_arg(_, 2), {times, 2}).

traces_in_separate_process() ->
    Pid = proc_lib:spawn_link(fun() -> mockgyver_dummy:return_arg(1) end),
    MRef = erlang:monitor(process, Pid),
    receive {'DOWN',MRef,_,_,_} -> ok end,
    ?WAS_CALLED(mockgyver_dummy:return_arg(_), once).
