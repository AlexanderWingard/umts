-module (index).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").

-include("umts_db.hrl").
-include("records.hrl").
main() ->
    case is_integer(wf:user()) orelse login:cookie_login() of
	false ->
	    wf:redirect("/login");
	true ->
	    #template { file="./templates/bare.html" }
    end.

title() -> "Main".

body() ->
    [#panel{id = leftnav, body = [user(), search()]},
     #panel{id = content, body = [sort(), content()]}].

content() ->
    [#panel{id = wtts, body = wtts([])}].

search() ->
    [#textbox{id = search, postback = search},
     #panel{id = searchPanel, body = []}].

user() ->
    User = umts_db:get_user(wf:user()),
    ["Signed in as: ", User#users.name, " ", #link{text = "Logout", postback = logout}].

sort()->
    [#panel{id = sort, body = [
			       #link{text = "Show all", url = "index" },
			       #checkbox{text = "Green", checked=true, id = chbg, postback = update_sort},
			       #checkbox{text = "Red", checked=true, id = chbr, postback = update_sort},
			       #checkbox{text = "Blue", checked=true, id = chbu, postback = update_sort},
			       #checkbox{text = "Black", checked=true, id = chbb, postback = update_sort},
			       #checkbox{text = "White", checked=true, id = chbw, postback = update_sort},
			       #checkbox{text = "Artifact", checked=true, id = chba, postback = update_sort},
			       #span{style="padding-left:50px", text = "Watch user:  " },
			       users_dropdown(),
			       time_dropdown(),
			       #span{style="padding-left:50px", text = "Show only:  " },
			       #checkbox{text ="Havers",checked=true, id = chbhavers, postback=update_sort},
			       #checkbox{text ="Wanters",checked=true, id = chbwanters, postback=update_sort},

			       #br{},
			       #hr{}
			      ]}].

users_dropdown()->
    #dropdown{ id = userlist, options = [ #option{text=X#users.name,
						  value=X#users.id} || X<-umts_db:get_users()],
	       postback = show_user
	     }.
time_dropdown() ->
    #dropdown{id = timespanlist, options = [ #option{text = "Select Timeperiod",
						     value = "undefined"},
					     #option{text = "One week",
						     value = "7"},
					     #option{text = "One Month",
						     value = "30"}],
	      postback = update_sort
	     }.

event(Event) ->
    case wf:user() of
	undefined ->
	    wf:redirect("/login");
	_ ->
	    handle_event(Event)
    end.

is_checked(CheckboxId, Default)->
    State = wf:state(CheckboxId),
    On = case State of
	     undefined -> Default;
	     _-> not State
	 end,
    wf:state(CheckboxId, On),
    On.

handle_event(logout) ->
    login:logout(),
    wf:redirect("/login");
handle_event(search) ->
    Request = wf:q(search),
    Result = umts_db:autocomplete_card(Request),
    Completions = [#card{uid = C} || C <- lists:sublist(Result, 10)],
    wf:update(searchPanel, [wf:f("Found ~w matching cards", [length(Result)]), Completions]);
handle_event(show_user)->
    [SelectedUserId] = wf:q(userlist),
    wf:update(wtts, show_user(SelectedUserId));

handle_event({wtt, Callback, Id}) ->
    %% TODO: Some more security here?
    User = wf:user(),
    umts_db:Callback(Id, User),
    umts_eventlog:log_wtt(User, Id, Callback),
    Card = #card{uid = Id},
    wf:replace("\#\#" ++ Id, Card),
    handle_event(update_sort);
handle_event(update_sort) ->
    Mapping = [{chbg, "G"}, {chbr, "R"}, {chbu, "U"}, {chbb, "B"}, {chbw, "W"}, {chba, "A"}],
    ColorFilter = lists:foldl(fun({Chb, Color}, Acc) ->
				      case wf:q(Chb) of
					  "on" ->
					      [Color | Acc];
					  undefined ->
					      Acc
				      end
			      end,
			      [],
			      Mapping),
    TimeFiler = case wf:q(timespanlist) of
		    "undefined" ->
			[];
		    Days ->
			list_to_integer(Days)
		end,
    WttFilter = case wf:q(chbwanters) of
		    undefined ->
			[#wtts.wanters];
		    "on" ->
			[]
		end ++
	case wf:q(chbhavers) of
	    undefined ->
		[#wtts.havers];
	    "on" ->
		[]
	end,
    wf:update(wtts, wtts([{color, ColorFilter}, {age, TimeFiler}, {wtt, WttFilter}])).

wtts(Filters) ->
    case catch list_to_integer(wf:path_info()) of
	UserID when is_integer(UserID) ->
            show_user(UserID);
	_ ->
	    [#card{uid = C} || C <- umts_db:all_wtts(Filters)]
    end.

show_user(UserID)->
    User = umts_db:get_user(UserID),
    [#h1{text = User#users.display},
						%    #link{text = "Show all", url = "index" },
     #h2{text = "Wants:"},
     [#card{uid = C} || C <- umts_db:user_wtts(UserID, #wtts.wanters)],
     #h2{text = "Haves:"},
     [#card{uid = C} || C <- umts_db:user_wtts(UserID, #wtts.havers)]].
