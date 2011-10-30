%%%-------------------------------------------------------------------
%%% @author Klas Johansson klas.johansson@gmail.com
%%% @copyright (C) 2011, Klas Johansson
%%% @private
%%% @doc Supervise the app.
%%% @end
%%%-------------------------------------------------------------------
-module(mockgyver_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init([]) ->
    Child = {mockgyver, {mockgyver, start_link, []},
             permanent, 10000, worker, [mockgyver]},
    {ok, {{one_for_one, 100, 60}, [Child]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
