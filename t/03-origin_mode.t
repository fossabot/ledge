use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 2) - 1;

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;
my $pwd = cwd();

our $HttpConfig = qq{
	lua_package_path "$pwd/../lua-resty-rack/lib/?.lua;$pwd/lib/?.lua;;";
    init_by_lua "
        rack = require 'resty.rack'
        ledge = require 'ledge.ledge'
        ledge.set('redis_database', $ENV{TEST_LEDGE_REDIS_DATABASE})
    ";
};

run_tests();

__DATA__
=== TEST 1: ORIGIN_MODE_NORMAL
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.set("origin_mode", ledge.ORIGIN_MODE_NORMAL)
            rack.use(ledge)
            rack.run()
        ';
    }
    location /__ledge_origin {
        more_set_headers  "Cache-Control public, max-age=600";
        echo "OK";
    }
--- request
GET /origin_mode
--- response_body
OK


=== TEST 2: ORIGIN_MODE_AVOID
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.set("origin_mode", ledge.ORIGIN_MODE_AVOID)
            rack.use(ledge)
            rack.run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode
--- response_body
OK


=== TEST 3: ORIGIN_MODE_BYPASS when cached
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode {
        content_by_lua '
            ledge.set("origin_mode", ledge.ORIGIN_MODE_BYPASS)
            rack.use(ledge)
            rack.run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode
--- response_body
OK

=== TEST 4: ORIGIN_MODE_BYPASS when we have nothing
--- http_config eval: $::HttpConfig
--- config
	location /origin_mode_bypass {
        content_by_lua '
            ledge.set("origin_mode", ledge.ORIGIN_MODE_BYPASS)
            rack.use(ledge)
            rack.run()
        ';
    }
    location /__ledge_origin {
        echo "ORIGIN";
    }
--- more_headers
Cache-Control: no-cache
--- request
GET /origin_mode_bypass
--- error_code: 503
