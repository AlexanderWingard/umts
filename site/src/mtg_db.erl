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
    {atomic, ok} = mnesia:create_table(requests, [{attributes, record_info(fields, requests)}]),
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

insert_request(Name) ->
    T = fun() ->
                NewID = mnesia:dirty_update_counter(auto_increment, requests, 1),
                ok = mnesia:write(#requests{id = NewID, name = Name}),
                NewID
        end,
    {atomic, NewID} = mnesia:transaction(T),
    NewID.

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

all(Table) ->
    Q = qlc:q([R || R <- mnesia:table(Table)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Res} = mnesia:transaction(T),
    Res.
    
