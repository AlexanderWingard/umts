-module(umts_db).
-compile(export_all).

-include("umts_db.hrl").
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

add_wanter(Id, User) -> update_wtt(Id, User, #wtts.wanters, fun
        ordsets:add_element/2, now()).
del_wanter(Id, User) -> update_wtt(Id, User, #wtts.wanters, fun
        ordsets:del_element/2, undefined).
add_haver(Id, User) -> update_wtt(Id, User, #wtts.havers, fun
        ordsets:add_element/2, now()).
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

all_wtts() ->
    Q = qlc:q([C || C <- mnesia:table(cards),
		    W <- mnesia:table(wtts),
		    C#cards.id == W#wtts.id]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
     Result.

user_wtts(User, Kind) ->
    Q = qlc:q([C || C <- mnesia:table(cards),
		    W <- mnesia:table(wtts),
		    C#cards.id == W#wtts.id,
		    ordsets:is_element(User, element(Kind, W))]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Result} = mnesia:transaction(T),
    Result.

get_updated_wtts()->
    Q = qlc:q([W || W <- mnesia:table(wtts),
            W#wtts.timestamp /= undefined]),
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
		
sort(Colors)->
        [C || C<-all_wtts(),
              X <- Colors,
              lists:member(X,C#cards.color)].

login(Name, Password) ->
    Q = qlc:q([U#users.id || U <- mnesia:table(users),
			     U#users.name == string:to_lower(Name), 
			     U#users.password == Password]),
    T = fun() -> qlc:e(Q) end,
    case mnesia:transaction(T) of
        {atomic, []} ->
            not_found;
        {atomic, [UserID]} ->
            UserID
    end.

autocomplete_card(Search) ->
    Q = qlc:q([C || C <- mnesia:table(cards),
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


all(Table) ->
    Q = qlc:q([R || R <- mnesia:table(Table)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Res} = mnesia:transaction(T),
    Res.
    
