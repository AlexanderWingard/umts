-module(umts_eventlog).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

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

get_events() ->
    Items = lists:flatmap(fun format_event/1, lists:reverse(lists:keysort(#events.time, umts_db:all(events)))),
    #list{body = Items}.

format_event(Event) ->
    case format_event_event(Event#events.event) of
	not_ok ->
	    [];
	Formated ->
	    [#listitem{text = wf:f("~w: ~s", [calendar:now_to_local_time(Event#events.time),
					      Formated])}]
    end.

format_event_event(#wtt_event{user = UserID, card = CardID, kind = Kind}) ->
    User = umts_db:get_user(UserID),
    Card = umts_db:get_card(CardID),
    Action = case Kind of 
		 add_wanter ->
		     "now wants";
		 del_wanter ->
		     "no longer wants";
		 add_haver ->
		     "now haves";
		 del_haver ->
		     "no longer haves"
	     end,
    wf:f("~s ~s ~s", [User#users.display, Action, Card#cards.name]);
format_event_event(#login_event{user = UserID}) ->
    User = umts_db:get_user(UserID),
    wf:f("~s logged in", [User#users.display]);
format_event_event(Event) ->
    not_ok.
