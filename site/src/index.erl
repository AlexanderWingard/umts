-module (index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("mtg_db.hrl").

main() -> #template { file="./templates/bare.html" }.

title() -> "Welcome to ///MTG".

body() ->
    [#panel{id = leftnav, body = search()},
     #panel{id = content, body = content()}
    ].

content() -> 
    [#panel{id = wtts, body = [card(C) || C <- mtg_db:all_wtts()]}].

search() ->
    [#textbox{id = search, postback = search},
     #panel{id = searchPanel, body = []}].

event(logout) ->
    wf:logout(),
    wf:redirect("/");
event(search) ->
    Request = wf:q(search),
    Result = mtg_db:autocomplete_card(Request),
    Completions = [(card(C))#panel{id = "srch" ++ C#cards.id} || C <- lists:sublist(Result, 10)],
    wf:update(searchPanel, [wf:f("Found ~w matching cards", [length(Result)]), Completions]);
event({wtt, Callback, Id}) ->
    mtg_db:Callback(Id, wf:user()),
    Card = card(mtg_db:get_card(Id)),
    wf:replace("srch" ++ Id, Card#panel{id = "srch" ++ Id}),
    wf:update(wtts, [card(C) || C <- mtg_db:all_wtts()]).

card(Card) ->
    Id = Card#cards.id,
    Wtt = mtg_db:get_wtts(Id),
    Iwant = ordsets:is_element(wf:user(), Wtt#wtts.wanters),
    Ihave = ordsets:is_element(wf:user(), Wtt#wtts.havers),
    WantPB = case Iwant of
		 true ->  {wtt, del_wanter, Id};
		 false -> {wtt, add_wanter, Id}
	     end,
    HavePB = case Ihave of
		 true -> {wtt, del_haver, Id};
		 false ->{wtt, add_haver, Id}
	     end,
    
    #panel{id = Id,
	   body = [
		   #image{image = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" ++ Card#cards.id ++ "&type=card",
			 style = "width: 223px; height: 310px;"},
		   #panel{body = [
				  tooltip("W: ", Wtt#wtts.wanters, Iwant, WantPB),
				  tooltip("H: ", Wtt#wtts.havers, Ihave, HavePB)
				 ],
			  style = "position: absolute; left: 10px; bottom: 10px"}
		  ],
	  style = "position: relative;"}.

tooltip(Prefix, Wtt, Iwtt, Postback) ->
    #panel{class= "wtt" ++ if Iwtt -> " iwtt"; true -> "" end, 
	   body = [#link{text = [Prefix, integer_to_list(length(Wtt))], postback = Postback},
		   #panel{body = [(mtg_db:get_user(U))#users.name || U <- Wtt]}]}.
