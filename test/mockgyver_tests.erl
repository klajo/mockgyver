-module(mockgyver_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include("../include/mockgyver.hrl").

was_called_test() ->
    mockgyver:start_link(),
    mockgyver:start_session([{x, test, 1}]),
    x:test(1),
    x:test(2),
    proc_lib:spawn(fun() -> x:test(2) end),
%    timer:sleep(100),
    ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([1]) -> ok end)}, once),
    ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {times, 2}),
    ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([2]) -> ok end)}, {at_least, 2}),
    ok = mockgyver:was_called({x, test, dbg:fun2ms(fun([3]) -> ok end)}, never).


parse_test() -> 
    mockgyver:start_session([{x, test, 1}]),
%%    ?WHEN(x:test(1) -> 42),
    x:test(1),
    x:test(2),
    x:test(2),
    ?WAS_CALLED(x:test(1), once),
    ?WAS_CALLED(x:test(2), {times, 2}),
    ?WAS_CALLED(x:test(_), {times, 2}),
    ?WAS_CALLED(x:test(_), any).
