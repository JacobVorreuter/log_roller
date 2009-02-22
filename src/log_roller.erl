%% Copyright (c) 2009 Jacob Vorreuter <jacob.vorreuter@gmail.com>
%% 
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%% 
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
-module(log_roller).
-author('jacob.vorreuter@gmail.com').
-behaviour(application).

-export([start/2, stop/1, init/1, start_phase/3, start_webtool/0, start_webtool/3]).
-export([build_rel/0, compile_templates/0, reload/0]).
	
%%%
%%% Application API
%%%

%% @doc start the application
start(_StartType, _StartArgs) -> 
	%% read log_roller_type (subscriber/publisher) from command line args
	%%	ex: erl -log_roller_type subscriber -boot log_roller
	case init:get_argument(log_roller_type) of 
		{ok,[["subscriber"]]} -> 
			supervisor:start_link({local, ?MODULE}, ?MODULE, []);
		_ -> % default is "publisher"
			ok = error_logger:add_report_handler(log_roller_h, []),
			{ok, self()}
	end.

%% @doc stop the application
stop(_) -> 
	ok.
	
%%%
%%% Internal functions
%%%

%% @hidden
init(_) ->
	{ok, {{one_for_one, 10, 10}, [
	    {log_roller_subscriber, {log_roller_subscriber, start_link, []}, permanent, 5000, worker, [log_roller_subscriber]},
		{log_roller_browser, {log_roller_browser, start_link, []}, permanent, 5000, worker, [log_roller_browser]}
	]}}.

%% @hidden
start_phase(world, _, _) ->
	net_adm:world(),
	ok;

%% @hidden
start_phase(type_action, _, _) ->
	case init:get_argument(log_roller_type) of 
		{ok,[["subscriber"]]} ->
			[log_roller_subscriber:subscribe_to(Node) || Node <- nodes()];
		_ -> 
			[log_roller_h:register_subscriber(Node) || Node <- nodes()]
	end, ok;
	
%% @hidden
start_phase(webtool, _, _) ->
	case init:get_argument(webtool) of 
		{ok,[["start"]]} ->
			start_webtool(),
			ok;
		_ -> 
			ok
	end.

%% @hidden		
start_webtool() -> 
	Port = 
		case application:get_env(log_roller, webtool_port) of
			undefined -> 8888;
			{ok, Val1} -> Val1
		end,
	BindAddr = 
		case application:get_env(log_roller, webtool_bindaddr) of
			undefined -> {0,0,0,0};
			{ok, Val2} -> Val2
		end,
	Server = 
		case application:get_env(log_roller, webtool_server) of
			undefined -> "localhost";
			{ok, Val3} -> Val3
		end,
	start_webtool(Port, BindAddr, Server).

%% @hidden	
start_webtool(Port, BindAddr, ServerName) ->
	webtool:start(standard_path, [{port,Port},{bind_address,BindAddr},{server_name,ServerName}]),
	webtool:start_tools([],"app=log_roller"),
	ok.

%% @hidden
build_rel() ->
    {ok, FD} = file:open("log_roller.rel", [write]),
    RootDir = code:root_dir(),
    Patterns = [
        {RootDir ++ "/", "erts-*"},
        {RootDir ++ "/lib/", "kernel-*"},
        {RootDir ++ "/lib/", "stdlib-*"}
    ],
    [Erts, Kerne, Stdl] = [begin
        [R | _ ] = filelib:wildcard(P, D),
        [_ | [Ra] ] = string:tokens(R, "-"),
        Ra
    end || {D, P} <- Patterns],
    RelInfo = {release,
        {"log_roller", "0.0.1"},
        {erts, Erts}, [
            {kernel, Kerne},
            {stdlib, Stdl},
            {log_roller, "0.0.1"}
        ]
    },
    io:format(FD, "~p.", [RelInfo]),
    file:close(FD),
    systools:make_script("log_roller", [local]),
    ok.

%% @hidden
compile_templates() ->
	case file:list_dir("templates") of
		{ok, Filenames} ->
			[begin
				erltl:compile("templates/" ++ Filename, [
								{outdir, "ebin"},
					       		report_errors, report_warnings, nowarn_unused_vars])
			 end || Filename <- Filenames];
		_ -> 
			exit(failure)
	end.

%% @doc purge and load all modules in app
reload() ->
    Modules = [
				log_roller, 
				log_roller_browser,
				log_roller_h,
				log_roller_subscriber,
				lr_webtool,
				rb_raw
			  ],
    lists:foreach(
        fun(Module) ->
            case code:is_loaded(Module) of
                false -> ok;
                {file, _Path} ->
                    code:purge(Module),
                    code:load_file(Module)
            end
        end,
        Modules
    ).