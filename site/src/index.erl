-module (index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("mtg_db.hrl").

main() -> #template { file="./templates/bare.html" }.

title() -> "Welcome to ///MTG".

body() ->
    #container_12 { body=[
        #grid_8 { alpha=true, prefix=2, suffix=2, omega=true, body=inner_body() }
    ]}.

inner_body() -> 
    case wf:user() of
        undefined ->
            [#panel{id = loginPanel, body = login_panel()}];
        _UserID ->
	    wf:wire(cards2, #event{type=keyup, postback = cards2}),
            [#panel{id = loginPanel, body = logged_in_panel()},
	     #panel{id = wtts, body = [card(C) || C <- mtg_db:all_wtts()]},
	     #panel{id = requestPanel, body = []}, 
	     #textbox_autocomplete{tag = cards},
	     #textbox{id = cards2}]
    end.

login_panel() ->
    [#textbox{id = userTextBox},
     #password{id = passwordTextBox, postback = login},
     #button{id = loginButton, text = "Login", postback = login},
     #label{id = loginFault, style = "display: none;", text = "Wrong username or password"}].

logged_in_panel() ->
    [#label{text = "Welcome " ++ integer_to_list(wf:user())},
     #button{id = logoutButton, text = "Logout", postback = logout}].

event(login) ->
    User = wf:q(userTextBox),
    Password = wf:q(passwordTextBox),
    
    case mtg_db:login(User, Password) of
        UserID when is_integer(UserID) ->
            wf:user(UserID),
            wf:redirect("/");
        not_found ->
            wf:wire(loginFault, #appear{})
    end;
event(logout) ->
    wf:logout(),
    wf:redirect("/");
event(cards2) ->
    Request = wf:q(cards2),
    Completions = [card(C) || C <- lists:sublist(mtg_db:autocomplete_card(Request), 4)],
    wf:update(requestPanel, Completions);
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

autocomplete_enter_event(SearchTerm, cards) ->
    List = [{struct,[{id, list_to_binary(C#cards.id) }, 
		     {label, list_to_binary(C#cards.name)}, 
		     {value, list_to_binary(C#cards.name)}]} || 
	       C <- mtg_db:autocomplete_card(SearchTerm)],
    mochijson2:encode(List).

autocomplete_select_event({struct, [{<<"id">>, Id },{<<"value">>, Value}]} , cards) ->
    wf:update(requestPanel, [#image{image = "http://gatherer.wizards.com/Handlers/Image.ashx?multiverseid=" ++ binary_to_list(Id) ++ "&type=card"}]),
    ok.
