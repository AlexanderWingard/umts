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
    Completions = [card(C) || C <- lists:sublist(Result, 10)],
    wf:update(searchPanel, [wf:f("Found ~w matching cards", [length(Result)]), Completions]);
event({wtt, Callback, Id}) ->
    mtg_db:Callback(Id, wf:user()),
    wf:replace(Id, card(mtg_db:get_card(Id))).

card(Card) ->
    Id = Card#cards.id,
    {Want, Have} = mtg_db:wtt_status(Id, wf:user()),
    Wtt = [
	   case Want of 
	       true ->
		   #link{text = "Don't want", postback = {wtt, del_wanter, Id}};
	       false ->
		   #link{text = "Want", postback = {wtt, add_wanter, Id}}
	   end,
	   "&nbsp;",
	   case Have of 
	       true ->
		   #link{text = "Don't have", postback = {wtt, del_haver, Id}};
	       false ->
	    #link{text = "Have", postback = {wtt, add_haver, Id}}
	   end
	  ],

    #panel{id = Card#cards.id,
	   body = [#image{image = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" ++ Card#cards.id ++ "&type=card", style="border: 1px solid black; width: 223, height: 310"},
		   Wtt
		  ]
	  }.
