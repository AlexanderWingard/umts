-module(mtg_db).
-compile(export_all).

-include("mtg_db.hrl").
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
    {atomic, ok} = mnesia:create_table(users, [{attributes, record_info(fields, users)}]),
    {atomic, ok} = mnesia:create_table(wtts, [{attributes, record_info(fields, wtts)}]),
    {atomic, ok} = mnesia:create_table(cards, [{attributes, record_info(fields, cards)}]),
    {atomic, ok} = mnesia:create_table(auto_increment, [{attributes, record_info(fields, auto_increment)}]).

insert_user(Name) ->
    T = fun() ->
                %% TODO: Prevent duplicate usernames
                NewID = mnesia:dirty_update_counter(auto_increment, users, 1),
                ok = mnesia:write(#users{id = NewID, name = Name, password ="secret"}),
                NewID
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
    
add_wanter(Id, User) -> update_wtt(Id, User, #wtts.wanters, fun ordsets:add_element/2).
del_wanter(Id, User) -> update_wtt(Id, User, #wtts.wanters, fun ordsets:del_element/2).
add_haver(Id, User) -> update_wtt(Id, User, #wtts.havers, fun ordsets:add_element/2).
del_haver(Id, User) -> update_wtt(Id, User, #wtts.havers, fun ordsets:del_element/2).

update_wtt(Id, User, Kind, Fun) ->
    T = fun() ->
		Old = case mnesia:read(wtts, Id) of
			  [Wtt] ->
			      Wtt;
			  [] ->
			      #wtts{id = Id}
		      end,
		Traders = element(Kind, Old),
		Updated = setelement(Kind, Old, Fun(User, Traders)),
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
		
    
login(Name, Password) ->
    Q = qlc:q([U#users.id || U <- mnesia:table(users), U#users.name == Name, U#users.password == Password]),
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
    
