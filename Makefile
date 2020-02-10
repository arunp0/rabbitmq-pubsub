all: clean build

build:
	./rebar3 compile

clean:
	./rebar3 clean

