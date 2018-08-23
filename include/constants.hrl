
-record(amqp_params, {
    exchange_name = <<"exchange_name">>,
    exchange_type = <<"topic">>,
    queue_name = <<"queue_name">>,
    routing_key = <<"routing_key">>,
    exchange_durable = true,
    queue_durable = true
}).
