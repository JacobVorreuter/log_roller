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
-module(log_roller_cache).
-author('jacob.vorreuter@gmail.com').

%% API exports
-export([start/1, store_cache/1, fetch_cache/0, get/1, put/2, delete/1]).

%% @spec start() -> Cache
%%		 Cache = cherly_cache()
start(_) -> 
	dict:new().
	
store_cache(Cache) -> 
	erlang:put(log_roller_cache, Cache).
	
fetch_cache() ->
	erlang:get(log_roller_cache).
	
%% @spec get(string()) -> undefined | any()
get(Key) when is_list(Key) ->
	case dict:find(Key, fetch_cache()) of
		error -> undefined;
		{ok, Val} -> Val
	end.
	
%% @spec put(list(), binary()) -> ok
put(Key, Val) when is_list(Key), is_binary(Val) ->
	store_cache(dict:store(Key, Val, fetch_cache())),
	ok;

put(_, _) ->
	{error, cache_value_must_be_binary}.

%% @spec delete(string()) -> ok
delete(Key) when is_list(Key) ->
	store_cache(dict:erase(Key, fetch_cache())),
	ok.