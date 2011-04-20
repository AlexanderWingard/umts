-module (index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("umts_db.hrl").

main() -> 
    case is_integer(wf:user()) orelse login:cookie_login() of
	false ->
	    wf:redirect("/login");
    true ->
	    wf:state(sort, [{havers,true},{wanters,
                    true},{color,"U"},{color,"G"},{color,"B"},{color,"W"},{color,"R"},{color,"A"}]),
        #template { file="./templates/bare.html" }
    end.

title() -> "Main".

body() ->
    [#panel{id = leftnav, body = [user(), search()]},
     #panel{id = content, body = [sort(), content()]}].

content() -> 
    [#panel{id = wtts, body = wtts()}].

search() ->
    [#textbox{id = search, postback = search},
     #panel{id = searchPanel, body = []}].

user() ->
    User = umts_db:get_user(wf:user()),
    ["Signed in as: ", User#users.name, " ", #link{text = "Logout", postback = logout}].

sort()->
    [#panel{id = sort, body = [
                #link{text = "Show all", url = "index" },
                #checkbox{text = "Green", checked=true,
                    postback={sort, "G", chbg}},
                #checkbox{text = "Red", checked=true,
                    postback={sort, "R", chbr}},
                #checkbox{text = "Blue", checked=true, postback={sort, "U",
                        chbu}},
                #checkbox{text = "Black", checked=true, postback={sort, "B",
                        chbb}},
                #checkbox{text = "White", checked=true, postback={sort, "W",
                        chbw}},
                #checkbox{text = "Artifact", checked=true, postback={sort, "A",
                        chba}},
                #span{style="padding-left:50px", text = "Watch user:  " },
                users_dropdown(),
                #span{style="padding-left:50px", text = "Show only:  " },
                #checkbox{text ="Havers",checked=true, postback={sort, havers, hv}},
                #checkbox{text ="Wanters",checked=true, postback={sort, wanters, wnt}},
                %% Padding
                #span{style="padding-left:50px", text=""},
                #link{text ="Trepartsbyten", url = "trepart" },

                #br{},
                #hr{}
        ]}].        

users_dropdown()->
    #dropdown{ id = userlist, value = "666", options = 
        [#option{text="---Choose one---",value="666"} |
        [ #option{text=X#users.name, value=X#users.id} ||
            X<-umts_db:get_users()]], 
        postback = show_user
    }.

dropbox()->
    #droppable{ tag=tradebox, accept_groups=cards, class="tradebox",
        body="bytesbox" }.

drop_event(T,R)->
    io:format("Hej: kort: ~w, drop: ~w ~n", [T,R]).
    
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

update_sortlist(Sort, _Id) when is_atom(Sort)->
    S = wf:state(sort),
    C = [{Sort, is_checked(Sort,false)}|lists:keydelete(Sort,1,S)],
    wf:state(sort,C),
    C;
    
update_sortlist(Color, Id)->
    S = wf:state(sort),
    C = case is_checked(Id, false) of
      true -> [{color,Color} |S];
      false -> lists:delete({color, Color}, S)
    end,
    wf:state(sort,C),
    C.
    
handle_event(logout) ->
    login:logout(),
    wf:redirect("/login");
handle_event(search) ->
    Request = wf:q(search),
    Result = umts_db:autocomplete_card(Request),
    Completions = [(card(C))#panel{id = "srch" ++ C#cards.id} || C <- lists:sublist(Result, 10)],
    wf:update(searchPanel, [wf:f("Found ~w matching cards", [length(Result)]), Completions]);
handle_event({sort, Sort, Id})->
    %% TODO: Fix this to a better handlingi
    C = update_sortlist(Sort,Id),
    wf:update(wtts, [card(X) || X<- umts_db:sort2(C)]);
handle_event(show_user)->
    wf:q(userlist),
    case wf:q(userlist)of
        "666"->ok;
        [SelectedUserId] -> wf:update(wtts, show_user(SelectedUserId))
    end;

handle_event({wtt, Callback, Id}) ->
    %% TODO: Some more security here?
    User = wf:user(),
    umts_db:Callback(Id, User),
    umts_eventlog:log_wtt(User, Id, Callback),
    Card = card(umts_db:get_card(Id)),
    wf:replace("srch" ++ Id, Card#panel{id = "srch" ++ Id}),
    %% TODO: Do we really need to redraw everything here?
    wf:update(wtts, wtts());

handle_event("666")->
    ok.

wtts() ->
    case catch list_to_integer(wf:path_info()) of
	    UserID when is_integer(UserID) ->
            show_user(UserID);
	 	_ ->
	        [card(C) || C <- umts_db:all_wtts()]
    end.

show_user(UserID)->        
    User = umts_db:get_user(UserID),
	[#h1{text = User#users.display},
%	 #link{text = "Show all", url = "index" },
     #h2{text = "Wants:"},
	 [card(C) || C <- umts_db:user_wtts(UserID, #wtts.wanters)],
	 #h2{text = "Haves:"},
	 [card(C) || C <- umts_db:user_wtts(UserID, #wtts.havers)]].

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
     %  #draggable{ class="drag", revert=false,clone=false,tag=Id,group=cards,
                  % body= 
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
