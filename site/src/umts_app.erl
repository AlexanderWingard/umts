-module (umts_app).
-export ([start/2, stop/0, do/1]).
-include_lib ("nitrogen_core/include/wf.hrl").

start(_, Port) ->
    inets:start(),
    umts_db:init(),
    {ok, Pid} = inets:start(httpd, [
        {port, Port},
	{ipfamily, inet},
        {server_name, "UMTS"},
        {server_root, "."},
        {document_root, "./static"},
        {modules, [?MODULE]},
        {mime_types, [{"css", "text/css"}, {"js", "text/javascript"}, {"html", "text/html"}]}
    ]),
    link(Pid),
    {ok, Pid}.

stop() ->
    inets:stop(),
    ok.

do(Info) ->
    RequestBridge = simple_bridge:make_request(inets_request_bridge, Info),
    ResponseBridge = simple_bridge:make_response(inets_response_bridge, Info),
    nitrogen:init_request(RequestBridge, ResponseBridge),

    %% Uncomment for basic authentication...
    %%nitrogen:handler(http_basic_auth_security_handler, basic_auth_callback_mod),

    nitrogen:run().
