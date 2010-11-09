-module (index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("umts_db.hrl").

main() -> 
    case wf:user() of
	undefined ->
	    wf:redirect("/login");
	_ ->
	    #template { file="./templates/bare.html" }
    end.

title() -> "Main".

body() ->
    [#panel{id = leftnav, body = [user(), search()]},
     #panel{id = content, body = content()}].

content() -> 
    [#panel{id = wtts, body = wtts()}].

search() ->
    [#textbox{id = search, postback = search},
     #panel{id = searchPanel, body = []}].

user() ->
    User = umts_db:get_user(wf:user()),
    ["Signed in as: ", User#users.name, " ", #link{text = "Logout", postback = logout}].

event(Event) ->
    case wf:user() of
	undefined ->
	    wf:redirect("/login");
	_ ->
	    handle_event(Event)
    end.

handle_event(logout) ->
    wf:logout(),
    wf:redirect("/login");
handle_event(search) ->
    Request = wf:q(search),
    Result = umts_db:autocomplete_card(Request),
    Completions = [(card(C))#panel{id = "srch" ++ C#cards.id} || C <- lists:sublist(Result, 10)],
    wf:update(searchPanel, [wf:f("Found ~w matching cards", [length(Result)]), Completions]);
handle_event({wtt, Callback, Id}) ->
    %% TODO: Some more security here?
    umts_db:Callback(Id, wf:user()),
    Card = card(umts_db:get_card(Id)),
    wf:replace("srch" ++ Id, Card#panel{id = "srch" ++ Id}),
    %% TODO: Do we really need to redraw everything here?
    wf:update(wtts, wtts()).

wtts() ->
    case catch list_to_integer(wf:path_info()) of
	UserID when is_integer(UserID) ->
	    User = umts_db:get_user(UserID),
	    [#h1{text = User#users.display},
	     #link{text = "Show all", url = "index" },
	     #h2{text = "Wants:"},
	     [card(C) || C <- umts_db:user_wtts(UserID, #wtts.wanters)],
	     #h2{text = "Haves:"},
	     [card(C) || C <- umts_db:user_wtts(UserID, #wtts.havers)]];
	_ ->
	    [card(C) || C <- umts_db:all_wtts()]
    end.

card(Card) ->
    Id = Card#cards.id,
    User = wf:user(),
    Wtt = umts_db:get_wtts(Id),
    Iwant = ordsets:is_element(User, Wtt#wtts.wanters),
    Ihave = ordsets:is_element(User, Wtt#wtts.havers),
    WantPB = case Iwant of
		 true ->  {wtt, del_wanter, Id};
		 false -> {wtt, add_wanter, Id}
	     end,
    HavePB = case Ihave of
		 true -> {wtt, del_haver, Id};
		 false ->{wtt, add_haver, Id}
	     end,

    Match = match_class(User, Iwant, Wtt#wtts.havers) orelse
	match_class(User, Ihave, Wtt#wtts.wanters),

    ExtraClass = if Match ->
			 " matchwtt";
		    Iwant orelse Ihave ->
			 " iwtt";
		    true ->
			 ""
		 end,

    #panel{id = Id,
	   class = "card",
	   body = [
		   #image{image = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" ++ Card#cards.id ++ "&type=card",
			  alt = Card#cards.name},
		   #panel{class = "wtt" ++ ExtraClass,
			   body = [
				  tooltip("W: ", "Wanters:", Wtt#wtts.wanters, WantPB),
				   "/",
				  tooltip("H: ", "Havers:", Wtt#wtts.havers,  HavePB)
				 ]}
		  ]}.

match_class(User, I, Wtt) ->
    I andalso ordsets:size(ordsets:del_element(User, Wtt)) > 0.
	    

tooltip(Prefix, Title, Wtt, Postback) ->
    #panel{class= "wtt2", 
	   body = [#link{text = [Prefix, integer_to_list(length(Wtt))], postback = Postback},
		   #panel{body = [#h3{text = Title}, 
				  #list{body = lists:map(fun(UserID) ->
								 User = umts_db:get_user(UserID),
								 #listitem{body = #link{text = User#users.display, 
											url = "/index/" ++ integer_to_list(User#users.id)}}
							 end,
							 Wtt)}]}]}.
