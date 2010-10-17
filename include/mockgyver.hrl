-ifndef(MOCKGYVER_HRL).
-define(MOCKGYVER_HRL, true).

-compile({parse_transform, mockgyver_xform}).

-define(WRAP(Type, Expr),
        {'$mock', Type, Expr}).

-define(MOCK(Expr), ?WRAP(m_init, (Expr))).

-define(WHEN(Expr),                 ?WRAP(m_when, if Expr; true -> ok end)).

%-define(WAS_CALLED(Expr),           ?WRAP(m_was_called, {Expr, once))).
-define(WAS_CALLED(Expr, Criteria), ?WRAP(m_was_called, {Expr, Criteria})).

-endif.
