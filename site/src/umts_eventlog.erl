-module(umts_eventlog).
-compile(export_all).
-include("umts_db.hrl").

log_login(User) ->
    log_event(#login_event{user = User}).

log_register(User) ->
    log_event(#register_event{user = User}).

log_wtt(User, Card, Kind) ->
    log_event(#wtt_event{user = User, card = Card, kind = Kind}).

log_event(Event) ->
    T = fun() ->
		mnesia:write(#events{time = now(), event = Event})
	end,
    {atomic, ok} = mnesia:transaction(T).
