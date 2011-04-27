-module(umts_db).
-compile(export_all).

-include("umts_db.hrl").
-include_lib("stdlib/include/ms_transform.hrl").
-include_lib("stdlib/include/qlc.hrl").

init() -> 
    mnesia:create_schema([node() | nodes()]),
    mnesia:start().

reinstall() ->
    mnesia:stop(),
    mnesia:delete_schema([node() | nodes()]),
    init(),
    create_tables().

create_tables() ->
    mnesia:create_table(users, [{attributes, record_info(fields, users)}, {disc_copies,[node()]}]),
    mnesia:create_table(wtts, [{attributes, record_info(fields, wtts)}, {disc_copies,[node()]}]),
    mnesia:create_table(cards, [{attributes, record_info(fields, cards)}, {disc_copies,[node()]}]),
    mnesia:create_table(events, [{attributes, record_info(fields, events)}, {disc_copies, [node()]}]),
    mnesia:create_table(auto_increment, [{attributes, record_info(fields, auto_increment)}, {disc_copies,[node()]}]).

insert_user(Name, Password, Email) ->
    Q = qlc:q([U#users.id || U <- mnesia:table(users),
			     U#users.name == Name]),
    T = fun() ->
		case qlc:e(Q) of
		    [] ->
			NewID = mnesia:dirty_update_counter(auto_increment, users, 1),
			ok = mnesia:write(#users{id = NewID,
						 name = string:to_lower(Name),
						 password = Password,
						 display = Name,
						 email = string:to_lower(Email)}),
			{ok, NewID};
		    [_Existing] ->
			{fault, exists}
		end
        end,
    {atomic, NewID} = mnesia:transaction(T),
    NewID. 

update_lastlogin(Id, Timestamp)->
    T = fun() ->
		[U] = mnesia:read(users, Id),
		ok = mnesia:write(U#users{lastlogin=Timestamp}) 
	end,
    {atomic, _} = mnesia:transaction(T),
    ok.

get_user(Id) ->
    T = fun() ->
		[User] = mnesia:read(users, Id),
		User
	end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

find_user_email(Email) ->
    T = fun() ->
		mnesia:match_object(#users{email = string:to_lower(Email), _ = '_'})
	end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

get_users()->
    Q = qlc:q([U || U <- mnesia:table(users)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result. 

add_wanter(Id, User) ->
    update_wtt(Id, User, #wtts.wanters, fun ordsets:add_element/2,now()).
del_wanter(Id, User) -> update_wtt(Id, User, #wtts.wanters, fun
								ordsets:del_element/2, undefined).
add_haver(Id, User) ->
    update_wtt(Id, User, #wtts.havers, fun ordsets:add_element/2, now()).
del_haver(Id, User) -> update_wtt(Id, User, #wtts.havers, fun
							      ordsets:del_element/2, undefined).

update_wtt(Id, User, Kind, Fun, Timestamp) ->
    T = fun() ->
		Old = case mnesia:read(wtts, Id) of
			  [Wtt] ->
			      Wtt;
			  [] ->
			      #wtts{id = Id}
		      end,
		Traders = element(Kind, Old),
		Updated1 = setelement(Kind, Old, Fun(User, Traders)),
		Updated = case Timestamp of
			      undefined -> Updated1;
			      _-> Updated1#wtts{timestamp=Timestamp}
			  end,
		case {ordsets:size(Updated#wtts.havers), ordsets:size(Updated#wtts.wanters)} of
		    {0, 0} ->
			ok = mnesia:delete({wtts, Id});
		    _ ->
			ok = mnesia:write(Updated)
		end,
		Updated
	end,
    {atomic, Wtt} = mnesia:transaction(T),
    Wtt.

all_wtts(Filters) ->
    Q = qlc:q([W#wtts.id || W <- mnesia:table(wtts),
			    C <- mnesia:table(cards),
			    W#wtts.id == C#cards.id,
			    filter(Filters, W, C)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

filter([{_Filter, []} | Filters], Wtt, Card) ->
    filter(Filters, Wtt, Card);
filter([{age, Days} | Filters], Wtt = #wtts{timestamp = Timestamp}, Card) ->
    {Mega, Secs, Milli} = now(),
    Then = {Mega, Secs - 86400 * Days, Milli},
    case Timestamp >= Then of
	true ->
	    filter(Filters, Wtt, Card);
	false ->
	    false
    end;
filter([{color, Colors} | Filters], Wtt, Card) ->
    case lists:any(fun(Color) -> lists:member(Color, Card#cards.color) end, Colors) of
	true ->
	    filter(Filters, Wtt, Card);
	false ->
	    false
    end;
filter([{wtt, WttIx} | Filters], Wtt, Card) ->
    case lists:any(fun(Ix) ->
			   length(element(Ix, Wtt)) > 0
		   end, WttIx) of
	true ->
	    filter(Filters, Wtt, Card);
	false ->
	    false
    end;
filter([], _, _) ->
    true.

user_wtts(User, Kind) ->
    Q = qlc:q([W#wtts.id || W <- mnesia:table(wtts),
			    ordsets:is_element(User, element(Kind, W))]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result. 

get_updated_wtts(LastLogin)->
    Q = qlc:q([W#wtts.id || W <- mnesia:table(wtts),
			    W#wtts.timestamp > LastLogin]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

get_wtts(Id) -> 
    T = fun() ->
		case mnesia:read(wtts, Id) of
		    [] ->
			#wtts{};
		    [Wtts] ->
			Wtts
		end
	end,
    {atomic, Res} = mnesia:transaction(T),
    Res.

login(Name, Password) when Name == undefined;
			   Password == undefined ->
    not_found;
login(Name, Password) ->
    Lower = string:to_lower(Name),
    MS = ets:fun2ms(fun(User = #users{name = Username,
				      password = CorrectPass})
			  when Username == Lower,
			       Password == CorrectPass->
			    User
		    end),
    T = fun() ->
		case mnesia:select(users, MS, write) of
		    [] ->
			not_found;
		    [User] ->
			wf:session(lastlogin, User#users.lastlogin),
			mnesia:write(User#users{lastlogin = now()}),
			User#users.id
		end
	end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

autocomplete_card(Search) ->
    Q = qlc:q([C#cards.id || C <- mnesia:table(cards),
			     string:str(string:to_lower(C#cards.name), string:to_lower(Search)) > 0]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Res} = mnesia:transaction(T),
    Res.

get_card(Id) -> 
    T = fun() ->
		[Card] = mnesia:read(cards, Id),
		Card
	end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

get_havers(CardId)->
    Q = qlc:q([W#wtts.havers || C <- mnesia:read(cards, CardId),
		    W <- mnesia:table(wtts),
		    C#cards.id == W#wtts.id]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

get_iwants(User)->
    Q = qlc:q([C || C <- mnesia:table(cards),
		    W <- mnesia:table(wtts),
		    C#cards.id == W#wtts.id,
            ordsets:is_element(User,W#wtts.wanters)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result.



all(Table) ->
    Q = qlc:q([R || R <- mnesia:table(Table)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Res} = mnesia:transaction(T),
    Res.
