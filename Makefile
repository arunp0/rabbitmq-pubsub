all: clean build get-deps

build:
	./rebar get-deps
	./rebar compile

get-deps:
	mkdir -p deps
	
	./rebar get-deps

	wget https://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.6.14/rabbit_common-3.6.14.ez
	unzip rabbit_common-3.6.14.ez
	rm -rf deps/rabbit_common
	mv -f rabbit_common-3.6.14 deps/rabbit_common
	rm -rf rabbit_common-3.6.14.ez
	
	wget https://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.6.14/amqp_client-3.6.14.ez
	unzip amqp_client-3.6.14.ez
	rm -rf deps/amqp_client
	mv amqp_client-3.6.14 deps/amqp_client
	rm -rf amqp_client-3.6.14.ez

fresh:
	rm -Rf deps
	./rebar clean

clean:
	./rebar clean
	rm -rf amqp_client-3.6.14.ez rabbit_common-3.6.14.ez
