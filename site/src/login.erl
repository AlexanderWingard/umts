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
     #br{},
     #link{text = "Forgot my password", postback = show_forgot},
     #lightbox{id = lbregister,  
	       body = [#panel{class = "confirmbox",
			      body = ["Confirm password:",
				      #password{id = password2, postback = confirm},
				      "E-mail:",
				      #textbox{id = email},
				      #button{text = "Confirm", postback = confirm},
				      #button{text = "Cancel", postback = cancel_lb}]}],
	       style = "display: none;"},
     #lightbox{id = lbforgot,  
	       body = [#panel{class = "confirmbox",
			      body = ["E-mail:",
				      #textbox{id = forgotemail},
				      #button{text = "Confirm", postback = forgot},
				      #button{text = "Cancel", postback = cancel_lb}]}],
	       style = "display: none;"}
    ].
	
event(login) ->
    Username = wf:q(username),
    Password = wf:q(password),
    case umts_db:login(Username, Password) of
	not_found ->
	    wf:flash("Incorrect username or password");
	Id ->
	    umts_eventlog:log_login(Id),
	    wf:user(Id),
	    wf:cookie(username, Username),
	    wf:cookie(password, Password),
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
	    wf:wire(lbregister, #show{})
    end;
event(confirm) ->
    Username = wf:q(username),
    Password = wf:q(password),
    Password2 = wf:q(password2),
    Email = wf:q(email),
    ValidEmail = validator_is_email:validate(null, Email),
    wf:wire(lbregister, #hide{}),
    if Password /= Password2 ->
	    wf:flash("Password doesn't match");
       not ValidEmail ->
	    wf:flash("Please enter a valid email");
       true ->
	    case umts_db:insert_user(Username, Password, Email) of
		{ok, NewID} ->
		    umts_eventlog:log_register(NewID),
		    wf:user(NewID),
		    wf:redirect("/");
		{fault, exists} ->
		    wf:flash("Username already exists")
	    end
    end;
event(forgot) ->
    Email = wf:q(forgotemail),
    wf:wire(lbforgot, #hide{}),
    case umts_db:find_user_email(Email) of 
	[] ->
	    wf:flash("No user with that email found");
	Emails ->
	    lists:foreach(fun send_forgotmail/1, Emails),
	    wf:flash("Information sent to " ++ Email)
    end;
event(show_forgot) ->
    wf:wire(lbforgot, #show{});
event(cancel_confirm) ->
    wf:wire(lb, #hide{});
event(cancel_lb) ->
    wf:wire(lbregister, #hide{}),
    wf:wire(lbforgot, #hide{}).

send_forgotmail(User) ->
    Msg = esmtp_mime:msg(User#users.email,
			 "alexander.wingard@gmail.com",
			 "UMTS login information",
			 "Username: " ++ User#users.name ++ "\nPassword: " ++ User#users.password),
    esmtp:send(Msg).

cookie_login() ->
    Username = wf:cookie(username),
    Password = wf:cookie(password),
    case umts_db:login(Username, Password) of
	not_found ->
	    false;
	Id ->
	    wf:user(Id),
	    true
    end.

logout() ->
    wf:cookie(username, undefined),
    wf:cookie(password, undefined),
    wf:logout().
