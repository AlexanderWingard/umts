-module (index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

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
            [#panel{id = loginPanel, body = logged_in_panel()}]
    end.

login_panel() ->
    [#textbox{id = userTextBox},
     #password{id = passwordTextBox},
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
            wf:update(loginPanel, logged_in_panel());
        not_found ->
            wf:wire(loginFault, #appear{})
    end;
event(logout) ->
    wf:logout(),
    wf:update(loginPanel, login_panel()).
