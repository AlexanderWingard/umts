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

login(Name, Password) ->
    Q = qlc:q([U#users.id || U <- mnesia:table(users), U#users.name == Name, U#users.password == Password]),
    T = fun() -> qlc:e(Q) end,
    case mnesia:transaction(T) of
        {atomic, []} ->
            not_found;
        {atomic, [UserID]} ->
            UserID
    end.

list_users() ->
    Q = qlc:q([U#users.name || U <- mnesia:table(users)]),
    T = fun() -> qlc:e(Q) end,
    {atomic, Res} = mnesia:transaction(T),
    Res.
    
