-record(users, {id, name, password, display, email, lastlogin}).
-record(wtts, {id, timestamp, wanters = ordsets:new(), havers = ordsets:new()}).
-record(auto_increment, {table, key}).
-record(cards, {id, name, color=[]}).
-record(events, {time, event}).
-record(login_event, {user}).
-record(register_event, {user}).
-record(wtt_event, {user, card, kind}).

%% mnesia:transform_table(users, fun({users, Id, Name, Password, Display, Email}) -> {users, Id, Name, Password, Display, Email, {0,0,0}} end, [id, name, password, display, email, lastlogin]).
