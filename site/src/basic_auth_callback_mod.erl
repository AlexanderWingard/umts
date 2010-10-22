%%%-------------------------------------------------------------------
%%% @author Manuel Durán Aguete <manueld@caixagalicia.es>
%%% @copyright (C) 2010, Manuel Durán Aguete
%%% @doc
%%%
%%% @end
%%% Created :  2 Jun 2010 by Manuel Durán Aguete <manueld@caixagalicia.es>
%%%-------------------------------------------------------------------
-module(basic_auth_callback_mod).
-include_lib ("nitrogen/include/wf.hrl").

%% API
-export([
    realm/0,
    is_protected/1,
    is_authenticated/2,
    authenticate/3
]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------
realm() ->
    "Protected Area".

%% Return true if the page should be protected.
is_protected(_Page) -> 
    true.

%% Return true if the user can access this page.
is_authenticated(_Module, _User) -> 
    is_integer(wf:user()).

%% Return true if the User and Password result in a successful authentication.
authenticate(_Module, User, Password) -> 
    case mtg_db:login(User, Password) of 
	not_found -> false;
	UserId  ->
	    wf:user(UserId),
	    true
    end.
