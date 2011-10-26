-ifndef(MOCKGYVER_HRL).
-define(MOCKGYVER_HRL, true).

-compile({parse_transform, mockgyver_xform}).

-define(WRAP(Type, Expr),
        {'$mock', Type, Expr}).

-define(MOCK(Expr), ?WRAP(m_init, (Expr))).

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

-endif.
