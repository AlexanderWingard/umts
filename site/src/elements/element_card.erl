-module (element_card).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").
-include("../../include/records.hrl").
-include("../../include/umts_db.hrl").

reflect() -> record_info(fields, card).

render_element(#card{uid = Id}) ->
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
		   #image{image = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" ++ Id ++ "&type=card"},
		   #panel{class = "wtt" ++ ExtraClass,
			  body = [tooltip("W: ", "Wanters:", Wtt#wtts.wanters, WantPB),
				  "/",
				  tooltip("H: ", "Havers:", Wtt#wtts.havers,  HavePB)
				 ]}
		  ]}.

match_class(User, I, Wtt) ->
    I andalso ordsets:size(ordsets:del_element(User, Wtt)) > 0.

tooltip(Prefix, Title, Wtt, Postback) ->
    Id = wf:temp_id(),
    wf:wire(Id, #event {type = click,
			delegate = ?MODULE,
			postback = Postback}),
    #panel{class= "wtt2", 
	   body = [#link{id = Id, text = [Prefix, integer_to_list(length(Wtt))]},
		   #panel{body = [#h3{text = Title}, 
				  #list{body = lists:map(fun(UserID) ->
								 User = umts_db:get_user(UserID),
								 #listitem{body = #link{text = User#users.display, 
											url = "/index/" ++ integer_to_list(User#users.id)}}
							 end,
							 Wtt)}]}]}.
event(Event) ->
    index:event(Event).
