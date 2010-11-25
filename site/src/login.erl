-module (login).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("umts_db.hrl").

main() -> #template { file="./templates/bare.html" }.

title() -> "Login".

body() ->
    #container_12{body = [#panel{id = logo,
				 body = [#h1{text = "UMTS"},
					 #p{body = "The ultimate magic trading system"}]
				},
			  #grid_8{id = loginbox,
				  alpha=true, 
				  prefix=2, 
				  suffix=2, 
				  omega=true, 
				  body=inner_body()
				 }
			 ]}.

inner_body() ->
    [#flash{},
     "Username:",
     #textbox{id = username},
     "Password:",
     #password{id = password, postback = login},
     #br{},
     #button{text = "Login", postback = login},
     #button{text = "Register", postback = register},
     #lightbox{id = lb,  
	       body = [#panel{id = confirmbox,
			      body = ["Confirm password:",
				      #password{id = password2, postback = confirm},
				      "E-mail:",
				      #textbox{id = email},
				      #button{text = "Confirm", postback = confirm},
				      #button{text = "Cancel", postback = cancel_confirm}]}],
	       style = "display: none;"}
    ].
	
event(login) ->
    Username = wf:q(username),
    Password = wf:q(password),
    case umts_db:login(Username, Password) of
	not_found ->
	    wf:flash("Incorrect username or password");
	Id ->
	    wf:user(Id),
	    wf:redirect("start")
    end;
event(register) ->
    Username = wf:q(username),
    Password = wf:q(password),
    case length(Username) == 0
	orelse length(Password) == 0 of 
	true ->
	    wf:flash("Please enter a username and password to register");
	false ->
	    wf:wire(lb, #show{})
    end;
event(confirm) ->
    Username = wf:q(username),
    Password = wf:q(password),
    Password2 = wf:q(password2),
    Email = wf:q(email),
    ValidEmail = validator_is_email:validate(null, Email),
    wf:wire(lb, #hide{}),
    if Password /= Password2 ->
	    wf:flash("Password doesn't match");
       not ValidEmail ->
	    wf:flash("Please enter a valid email");
       true ->
	    case umts_db:insert_user(Username, Password, Email) of
		{ok, NewID} ->
		    wf:user(NewID),
		    wf:redirect("/");
		{fault, exists} ->
		    wf:flash("Username already exists")
	    end
    end;
event(cancel_confirm) ->
    wf:wire(lb, #hide{}).
