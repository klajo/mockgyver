-ifndef(MOCKGYVER_HRL).
-define(MOCKGYVER_HRL, true).

-include_lib("eunit_addons/include/eunit_addons.hrl").

-compile({parse_transform, mockgyver_xform}).

%% run tests with a mock
-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                          Tests),
        {timeout, ForAllTimeout,
         {setup,
          fun() -> mockgyver:start_session(?MOCK_SESSION_PARAMS) end,
          fun(_) -> mockgyver:end_session() end,
          [{timeout, PerTcTimeout,          % timeout for each test
            {spawn,
             {atom_to_list(__Test),         % label per test
              fun() ->
                      try
                          case mockgyver:start_session_element() of
                              ok ->
                                  Env = SetupFun(),
                                  try
                                      apply(?MODULE, __Test, [Env])
                                  after
                                      CleanupFun(Env)
                                  end;
                              {error, Reason} ->
                                  error({mockgyver_session_elem_fail, Reason})
                          end
                      after
                          mockgyver:end_session_element()
                      end
              end}}}
           || __Test <- Tests]}}).

-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout),
        ?WITH_MOCKED_SETUP(SetupFun, CleanupFun, ForAllTimeout, PerTcTimeout,
                           eunit_addons:get_tests_with_setup(?MODULE))).

-define(WITH_MOCKED_SETUP(SetupFun, CleanupFun),
        ?WITH_MOCKED_SETUP(SetupFun, CleanupFun,
                           ?FOR_ALL_TIMEOUT, ?PER_TC_TIMEOUT)).

-define(WRAP(Type),
        {'$mock', Type, {?FILE, ?LINE}}).

-define(WRAP(Type, Expr),
        {'$mock', Type, Expr, {?FILE, ?LINE}}).

-define(MOCK_SESSION_PARAMS, ?WRAP(m_session_params)).

-define(MOCK(Expr), mockgyver:exec(?MOCK_SESSION_PARAMS, (Expr))).

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
