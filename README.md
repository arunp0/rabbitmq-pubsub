# erlang_amqp_client
Layer on top of rabbitmq client (erlang amqp client) to multiplex sub connections among several subscriptor/publisher processes in pubsub


# Erlang code for RabbitMQ tutorials #

Here you can find a Erlang code examples from [RabbitMQ
tutorials](http://www.rabbitmq.com/getstarted.html).

This code is using [RabbitMQ Erlang
Client](http://hg.rabbitmq.com/rabbitmq-erlang-client/) ([User
Guide](http://www.rabbitmq.com/erlang-client-user-guide.html)).

## Requirements

To run this code you need at least [Erlang
R13B03](http://erlang.org/download.html), on Ubuntu you can get it
using apt:

    sudo apt-get install erlang

You need Erlang Client binaries:

    wget https://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.6.14/rabbit_common-3.6.14.ez
    unzip rabbit_common-3.6.14.ez
    ln -s rabbit_common-3.6.14 rabbit_common

    wget https://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.6.14/amqp_client-3.6.14.ez
    unzip amqp_client-3.6.14.ez
    ln -s amqp_client-3.6.14 amqp_client

    wget https://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.6.14/recon-2.3.2.ez
    unzip recon-2.3.2.ez
    ln -s recon-2.3.2 recon

In Erlang Shell

  > c(amqp_pubsub).  
  > rr(amqp_pubsub).

  Start Consumers

  > amqp_pubsub:start_link(consumer0).

  > amqp_pubsub:subscribe(consumer0, #amqp_params{
      exchange_name = <<"exchange_name">>,
      exchange_type = <<"topic">>,
      queue_name = <<"queue_name">>,
      routing_key = <<"routing_key">>,
      exchange_durable = true,
      queue_durable = true
  }).

  Publish Messages

  > amqp_pubsub:start_link(publish0).

  > amqp_pubsub:publish(publish0, #amqp_params{
      exchange_name = <<"exchange_name">>,
      exchange_type = <<"topic">>,
      queue_name = <<"queue_name">>,
      routing_key = <<"routing_key">>,
      exchange_durable = true,
      queue_durable = true
  },<<"arun">>).

  > amqp_pubsub:publish(publish0, #amqp_params{
      exchange_name = <<"exchange_name">>,
      exchange_type = <<"topic">>,
      queue_name = <<"queue_name">>,
      routing_key = <<"routing_key">>,
      exchange_durable = true,
      queue_durable = true
  },<<"arun new message">>).
