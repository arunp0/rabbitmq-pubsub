% MIT License

% Copyright (c) 2018 arunp0

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:

% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.

% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.

%% @doc The module that handles the resolution of a single DNS question.
%%
%% The meat of the resolution occurs in erldns_resolver:resolve/3

-module(amqp_pubsub).

-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("constants.hrl").

-export([
            start_link/0,
            start_link/1,
            init/1,
            subscribe/1,
            subscribe/2,
            subscribe/3,
            publish/2,
            publish/3,
            default_callback/2
        ]).

-export([
    handle_call/3, handle_cast/2
]).

-record(state, {
    connection,
    channel,
    queues = dict:new(),
    exchanges = dict:new(),
    exchanges_bound = dict:new(),
    routes_bound = dict:new()
}).

-spec start_link() -> {ok, Pid::pid()} | {error, Reason::term()}.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [?MODULE], []).

-spec start_link(atom()) -> {ok, Pid::pid()} | {error, Reason::term()}.

start_link(ServerName) ->
    gen_server:start_link({local, ServerName}, ?MODULE, [?MODULE], []).

subscribe(AmqpParams) ->
    subscribe(?MODULE, AmqpParams, fun default_callback/2).

subscribe(ServerName, AmqpParams) ->
    subscribe(ServerName, AmqpParams, fun default_callback/2).

subscribe(ServerName, AmqpParams, CallBack) ->
    gen_server:call(ServerName, {setup_exchange, AmqpParams}),
    {ok, Queue} = gen_server:call(ServerName, {setup_queue, AmqpParams}),
    gen_server:call(ServerName, {subscribe, ServerName, Queue, AmqpParams, CallBack}).

publish(AmqpParams, Message)->
    publish(?MODULE, AmqpParams, Message).

publish(ServerName, AmqpParams, Message)->
    gen_server:call(ServerName, {setup_exchange, AmqpParams}),
    gen_server:call(ServerName, {setup_queue, AmqpParams}),
    gen_server:cast(ServerName, {publish, AmqpParams, Message}).

init([ServerName]) ->
    io:format("Starting ~p", [ServerName]),
    {ok, Connection} = get_connection(),
    {ok, Channel} = get_channel(Connection),
    State = #state{
        connection = Connection,
        channel = Channel
    },
    {ok, State}.

get_connection() ->
    amqp_connection:start(#amqp_params_network{
        host = os:getenv(<<"AMQP_HOST">>, "localhost"),
        port = list_to_integer(
            os:getenv(<<"AMQP_PORT">>, "5672")
        ),
        username = list_to_binary(os:getenv(<<"AMQP_USERNAME">>, "guest")),
        password = list_to_binary(os:getenv(<<"AMQP_PASSWORD">>, "guest")),
        heartbeat = list_to_integer(
            os:getenv(<<"AMQP_HEARTBEAT">>, "10")
        )
    }).

get_channel(Connection) ->
    amqp_connection:open_channel(Connection).

default_callback(RoutingKey, Body) ->
    io:format(" [x] ~p:~p~n", [RoutingKey, Body]),
    {ok, true}.

get_or_create_queue(AmqpParams, State) ->
    IsNewQueue = (
        dict:is_empty(State#state.queues) or
        not(dict:is_key(AmqpParams#amqp_params.queue_name, State#state.queues))
    ),
    case IsNewQueue of
        true ->
            #'queue.declare_ok'{queue = Queue} =
                amqp_channel:call(State#state.channel, #'queue.declare'{
                    queue = AmqpParams#amqp_params.queue_name,
                    durable = AmqpParams#amqp_params.queue_durable
                }),
            State1 = State#state{
                queues = dict:store(
                    AmqpParams#amqp_params.queue_name,
                    Queue,
                    State#state.queues
                )
            };
        false ->
            Queue = dict:fetch(AmqpParams#amqp_params.queue_name, State#state.queues),
            State1 = State
    end,
    {ok, [Queue, State1]}.

handle_call({setup_exchange, AmqpParams}, _From, State) ->
    IsNewExchange = dict:is_empty(State#state.exchanges)
            or not(dict:is_key(AmqpParams#amqp_params.exchange_name, State#state.exchanges)),
    case IsNewExchange of
        true ->
            amqp_channel:call(State#state.channel, #'exchange.declare'{
                exchange = AmqpParams#amqp_params.exchange_name,
                type = AmqpParams#amqp_params.exchange_type,
                durable = AmqpParams#amqp_params.exchange_durable
            }),
            State1 = State#state{
                exchanges = dict:store(
                    AmqpParams#amqp_params.exchange_name,
                    true,
                    State#state.exchanges
                )
            };
        false ->
            State1 = State
    end,
    {reply, {ok}, State1};

handle_call({setup_queue, AmqpParams}, _From, State) ->
    {ok, [Queue, State1]} = get_or_create_queue(AmqpParams, State),
    IsQueueBound =  not(
        dict:is_empty(State#state.exchanges_bound) or
        not(dict:is_key(AmqpParams#amqp_params.exchange_name, State#state.exchanges_bound)) or
        dict:is_empty(State#state.routes_bound) or
        not(dict:is_key(AmqpParams#amqp_params.routing_key, State#state.routes_bound))
    ),
    case IsQueueBound of
        false ->
            amqp_channel:call(State#state.channel, #'queue.bind'{
                exchange = AmqpParams#amqp_params.exchange_name,
                routing_key = AmqpParams#amqp_params.routing_key,
                queue = Queue
            }),
            State2 = State1#state{
                exchanges_bound =  dict:store(
                    AmqpParams#amqp_params.exchange_name,
                    Queue,
                    State#state.exchanges_bound
                ),
                routes_bound = dict:store(
                    AmqpParams#amqp_params.routing_key,
                    Queue,
                    State#state.routes_bound
                )
            };
        true ->
            State2 = State1
    end,
    {reply, {ok, Queue}, State2};

handle_call({subscribe, ServerName, Queue, AmqpParams, CallBack}, _From, State) ->
    amqp_channel:subscribe(State#state.channel, #'basic.consume'{
            queue = Queue,
            no_ack = true
        },
        self()
    ),
    receive
        #'basic.consume_ok'{} -> ok
    end,
    gen_server:cast(ServerName, {subscribe, AmqpParams, CallBack}),
    {reply, {ok}, State};

handle_call({publish, AmqpParams, Message}, _From, State) ->
    amqp_channel:cast(State#state.channel,
        #'basic.publish'{
            exchange = AmqpParams#amqp_params.exchange_name,
            routing_key = AmqpParams#amqp_params.routing_key
        },
        #amqp_msg{payload = Message}),
    io:format(" [x] Sent ~p ~n", [Message]),
    {reply, {ok}, State}.

%% Async functions

subscribe_callback(AmqpParams, CallBack) ->
    RoutingKey = AmqpParams#amqp_params.routing_key,
    receive
        {#'basic.deliver'{routing_key = RoutingKey},
                #amqp_msg{payload = Body}
            } ->
        CallBack(RoutingKey, Body),
        subscribe_callback(AmqpParams, CallBack)
    after 1000 ->
        subscribe_callback(AmqpParams, CallBack)
    end.

handle_cast({publish, AmqpParams, Message}, State) ->
    amqp_channel:cast(State#state.channel,
        #'basic.publish'{
          exchange = AmqpParams#amqp_params.exchange_name,
          routing_key = AmqpParams#amqp_params.routing_key
        },
        #amqp_msg{payload = Message}),
    io:format(" [x] Sent ~p ~n", [Message]),
    {noreply, State};

handle_cast({subscribe, AmqpParams, CallBack}, State) ->
    subscribe_callback(AmqpParams, CallBack),
    {noreply, State}.
