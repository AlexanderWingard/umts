-module(umts_parser).
-compile(export_all).

-include("umts_db.hrl").
-define(COLORS, "WUGRB").

parse() -> 
    lists:foreach(fun parse/1, filelib:wildcard("MagicDB/*.xml")).

parse(File)  ->
    {ok, {_, Cards}, _Rest} = 
	xmerl_sax_parser:file(File, [{event_fun, fun event_fun/3},
				     {event_state, {0, []}}]),
    T = fun() ->
		lists:foreach(fun(Card) ->
				      mnesia:write(Card)
			      end, Cards)
	end,
    mnesia:transaction(T). 

event_fun({startElement,[],"mc",{[],"mc"},[]}, _, {Next, Acc}) ->
    {0, [#cards{} | Acc]};
event_fun({startElement,[],"id",{[],"id"},[]}, _, {Next, Acc}) ->
    {#cards.id, Acc};
event_fun({startElement,[],"name",{[],"name"},[]}, _, {Next, Acc}) ->
    {#cards.name, Acc};
event_fun({startElement,[],"cost",{[],"cost"},[]}, _, {Next, Acc}) ->
    {#cards.color, Acc};
event_fun({characters, Characters}, _, {Next, [Card | Acc]}) when 
    Next == #cards.color ->
        Colors = lists:usort([[X] || X<-Characters, lists:member(X,?COLORS)]),
        C = case Colors of
        [] -> ["A"];
                    X -> X
        end,
        {0, [setelement(Next, Card, C) | Acc]};
event_fun({characters, Characters}, _, {Next, [Card | Acc]}) when Next > 0 ->
    {0, [setelement(Next, Card, Characters) | Acc]};
event_fun(Event, Location, {Next, Acc}) ->
    {0, Acc}.

