#!/usr/bin/perl

# This is a trivial example of the RPC interface. You'll need RPC::XML
# on your system (not for the server itself, but for this test script).

require RPC::XML;
require RPC::XML::Client;

my $cli = RPC::XML::Client->new('http://localhost:9000/plugins/RPC/rpc.xml');

my $resp = $cli->send_request('slim.doCommand', undef, [ 'player', 'count', '?' ]);

# Some other things to try: (substitute MAC address as appropriate)
#my $resp = $cli->send_request('slim.doCommand', '00:04:20:05:a0:65', [ 'pause' ]);
#my $resp = $cli->send_request('system.listMethods');

if ($resp->is_fault) {
	print "Fault: " . $resp->string . "\n";
} else {
	if ($resp->isa("RPC::XML::array")) {
		print "'" . join("', '", @{$resp->value()}) . "'\n";
	} else {
		# need a better way to pretty-print the response
		print "(Array expected)\n";
	}
}
