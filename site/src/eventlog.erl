-module(eventlog).
-compile(export_all).
-include_lib("nitrogen_core/include/wf.hrl").

-include("umts_db.hrl").

main() ->
    #template{file = "./templates/bare.html"}.

title() ->
    "Recent events".

body() ->
    #container_12{body = [#grid_8{
				  alpha=true, 
				  prefix=2, 
				  suffix=2, 
				  omega=true, 
				  body=umts_eventlog:get_events()
				 }]}.
