-ifndef(MOCKGYVER_HRL).
-define(MOCKGYVER_HRL, true).

-include_lib("eunit_addons/include/eunit_addons.hrl").

-compile({parse_transform, mockgyver_xform}).

-ifdef(OTP_RELEASE).
-define(mockgyver_get_stacktrace__(),
        try error(get_stack)
        catch error:get_stack:St -> St
        end).
-else. % OTP_RELEASE
-define(mockgyver_get_stacktrace__(),
        try error(get_stack)
        catch error:get_stack -> erlang:get_stacktrace()
        end).
-endif. % OTP_RELEASE.



%% run tests with a mock
-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                          Tests, MockOpts),
        %% Wrap it in a fun so we can have a few local variables
        fun() ->
                StackId = erlang:phash2(?mockgyver_get_stacktrace__()),
                Base = #{num_sessions => length(Tests),
                         signature => {?FILE, ?LINE, ?FUNCTION_NAME, StackId}},
                IndexedTests = lists:zip(lists:seq(1, length(Tests)),
                                         Tests),
                {timeout, ForAllTimeout,           %% timeout for all tests
                 [{timeout, PerTcTimeout,          %% timeout for each test
                   {spawn,
                    {atom_to_list(__Test),         %% label per test
                     fun() ->
                             MockSeqInfo = Base#{index => I},
                             ?MOCK(fun() ->
                                           Env = SetupFun(),
                                           try
                                               apply(?MODULE, __Test, [Env])
                                           after
                                               CleanupFun(Env)
                                           end
                                   end,
                                   MockOpts ++ [{mock_sequence, MockSeqInfo}])
                     end}}}
                  || {I, __Test} <- IndexedTests]}
        end()).

-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                          Tests),
        ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                           Tests, [])).

-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout),
        ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                           eunit_addons:get_tests_with_setup(?MODULE))).

-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun),
        ?WITH_MOCKED_SETUP(SetupFun, CleanupFun,
                           ?FOR_ALL_TIMEOUT, ?PER_TC_TIMEOUT)).

-define(WRAP(Type, Expr),
        {'$mock', Type, Expr, {?FILE, ?LINE}}).

-define(MOCK(Expr), ?WRAP(m_init, {(Expr), []})).

-define(MOCK(Expr, MockOpts), ?WRAP(m_init, {(Expr), MockOpts})).

-define(WHEN(Expr), ?WRAP(m_when, case x of Expr end)).

-define(VERIFY(Expr, Args),
        ?WRAP(m_verify, {case x of Expr -> ok end, Args})).

-define(WAS_CALLED(Expr),
        ?WAS_CALLED(Expr, once)).
-define(WAS_CALLED(Expr, Criteria),
        ?VERIFY(Expr, {was_called, Criteria})).

-define(WAIT_CALLED(Expr),
        ?WAIT_CALLED(Expr, once)).
-define(WAIT_CALLED(Expr, Criteria),
        ?VERIFY(Expr, {wait_called, Criteria})).

-define(NUM_CALLS(Expr),
        ?VERIFY(Expr, num_calls)).

-define(GET_CALLS(Expr),
        ?VERIFY(Expr, get_calls)).

-define(FORGET_WHEN(Expr),
        ?VERIFY(Expr, forget_when)).

-define(FORGET_CALLS(Expr),
        ?VERIFY(Expr, forget_calls)).

-define(FORGET_CALLS(),
        mockgyver:forget_all_calls()).

-endif.
