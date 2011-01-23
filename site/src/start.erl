-module (start).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").

-include("umts_db.hrl").
-include("records.hrl").
-define(NBR_NEWLY,9).
main() -> #template { file="./templates/bare.html" }.

title() -> "Login".

body() ->
    [#panel{id = newly, body = [
				#container_12{body = 
						  [#panel{id = logo,
							  body = [#h1{text = "UMTS"},
								  #p{body = "The ultimate magic trading system"}]
							 },
						   
						   #link{text="Goto 10 (Index)", url = "index"},
						   #grid_8{id = cardbox,
							   alpha=true, 
							   prefix=2, 
							   suffix=2, 
							   omega=true, 
							   body=timestamp()
							  }]}]}].

timestamp()->
    LastLogin = wf:session_default(lastlogin, now()),
    [#flash{},#h2{text="Added cards since last login"},
     [#card{uid = W} || W <- umts_db:get_updated_wtts(LastLogin)]].
