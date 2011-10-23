-module(mockgyver_dummy).

-export([return_arg/1, return_arg/2, return_arg2/1]).

return_arg(N) ->
    N.

return_arg(M, N) ->
    {M, N}.

return_arg2(N) ->
    N.
