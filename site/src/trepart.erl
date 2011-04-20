-module (trepart).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").

-include("umts_db.hrl").
main() -> #template { file="./templates/bare.html" }.

title() -> "Login".

body() ->
    [#panel{id = trepart, body = [
            #container_12{body = 
                [#panel{id = logo,
				          body = [#h1{text = "UMTS"},
					              #p{body = "The ultimate magic trading system"}]
				        },
                #link{text="Goto 10 (Index)", url = "index"},
                #panel{body=[timestamp()]}
            ]
            }    
        ]
    }].
                
timestamp()->
    UserId = wf:user(),
    K = populate_edges(UserId,ordsets:new()),
    Result = proplists:get_all_values(UserId,K),
    R = fix(UserId,Result, K, []),
    TreParts = fix2(R,[],K),
    case TreParts of
        [] -> [#h2{text="Hej"}];
        _ ->
            [ show_card_and_label(X) || X<-TreParts]
    end.

    show_card_and_label({ {F1,T1,C1}, {F2,T2,C2}, {F3,T3,C3}})->
        F1U = umts_db:get_user(F1),
        F2U = umts_db:get_user(F2),
        F3U = umts_db:get_user(F3),
        
        T1U = umts_db:get_user(T1),
        T2U = umts_db:get_user(T2),
        T3U = umts_db:get_user(T3),
        
        C1U = index:card(umts_db:get_card(C1)),
        C2U = index:card(umts_db:get_card(C2)),
        C3U = index:card(umts_db:get_card(C3)),
        
        Row1 = #tablerow{ cells=[
                #tablecell{text=F1U#users.name++" -> "++T1U#users.name},
                #tablecell{text=F2U#users.name++" -> "++T2U#users.name},
                #tablecell{text=F3U#users.name++" -> "++T3U#users.name}
            ]},
        Row2 = #tablerow{ cells=[
                #tablecell{body=C1U},
                #tablecell{body=C2U},
                #tablecell{body=C3U}
            ]},
        [#h2{text="Trepartsbyten for anvandare "++F1U#users.name},
            #table{ rows = [Row1,Row2] }].

%% adds havers for a card 
populate_card(_,[], L)->L;
populate_card(User, [C|T], L)->
    H = get_havers(C),
    R = lists:foldl(fun(X,P)->
            ordsets:add_element({User,{X, C#cards.id}}, P)
    end, L,H),
    populate_card(User, T, R). 

populate_edges(User, L)->
    {E1,E2}= populate_user(L, [User]),
    {E3,E4} =  populate_user(E2,E1),
    {_E5,E6} =  populate_user(E4,E3),
    E6. 
populate_user(L, R)->
    F = lists:foldl(fun(E,AccIn)->
            List = get_wants(E),
            populate_card(E, List, AccIn)
    end, ordsets:new(), R),

    K = ordsets:fold(fun({_,{X,_}},Y)->
            ordsets:add_element(X,Y)
    end, ordsets:new(), F),
        {ordsets:to_list(K), ordsets:union(F,L)}.

    
k()->
    K = populate_edges(ett,ordsets:new()),
    Result = proplists:get_all_values(ett,K),
    R = fix(ett,Result, K, []),
    fix2(R,[],K).

fix(_,[],_,Res)->Res;
fix(U,[{To, C}|T],K, Res)->
    R =proplists:get_all_values(To,K),
     case R of
        [] -> fix(U,T,K,Res);
        _-> fix(U,T,K, [{{U,To,C},{To,X,Y}}||{X,Y}<-R]++Res)
    end.

fix2([],R,_)->R;
fix2([{{A1,A2,A3},{F,T,C}}|Rest],Resu,K)->
    R =proplists:get_all_values(T,K),
    case R of
        [] -> fix2(Rest,Resu,K);
        _->
           fix2(Rest, [{{A1,A2,A3},{F,T,C},{T,X,Y}}||{X,Y}<-R, X==A1]++Resu,K)
    end.


get_wants(UserId)->
    umts_db:get_iwants(UserId).

get_havers(Card)->
    lists:flatten(umts_db:get_havers(Card#cards.id)).
    
     
   
