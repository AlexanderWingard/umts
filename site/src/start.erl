-module (start).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("umts_db.hrl").
-define(NBR_NEWLY,5).
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
    Sorted = lists:keysort(#wtts.timestamp, umts_db:get_updated_wtts()),
    [#flash{},#h2{text="Newly added cards"},
        [index:card(umts_db:get_card( W#wtts.id )) ||
            W<-lists:sublist(Sorted,?NBR_NEWLY)]].


