#!/usr/bin/perl
use strict;
use warnings;

use Socket;
use Fcntl;

my $NL = "\r\n";

sub mk_server_socket {
    # {{{
    my ($addr, $port, $queue_len) = @_;
    my $socket_fh;

    socket(
        $socket_fh,
        AF_INET,
        SOCK_STREAM,
        getprotobyname("tcp")
    ) || die "socket: $!";

    setsockopt(
        $socket_fh,
        SOL_SOCKET,
        SO_REUSEADDR,
        pack("l", 1)
    ) || die "setsockopt: $!";

    bind(
        $socket_fh,
        pack_sockaddr_in(
            $port,
            inet_aton($addr)
        )
    ) || die "bind $!";

    listen(
        $socket_fh,
        $queue_len
    ) || die "listen $!";

    return $socket_fh;
} # }}}

my $socket_fh = mk_server_socket("127.0.0.1", 8000, 10);
print "Server started\n";

for (my $paddr; $paddr = accept(my $client, $socket_fh); close $client) {
    my ($port, $iaddr) = sockaddr_in($paddr);
    my $name = gethostbyaddr($iaddr, AF_INET);

    print "connection from $name [", inet_ntoa($iaddr), "]\n";

    my $flags = fcntl($client, F_GETFL, 0);
    fcntl($client, F_SETFL, $flags | O_NONBLOCK);

    {
        my $rin = '';
        vec($rin, fileno($client), 1) = 1;

        select(my $rout = $rin, undef, undef, 3);

        if($rin ne $rout) {
            # Timeout
            print "connection timed out.\n";
            last;
        }
    }

    # Process request
    my ($method, $path, $http_ver);
    my @headers = ();
    my @content = ();
    {
        local $/ = $NL;
        my $line;
        my $statusline = <$client>;

        while (defined($line = <$client>) && $line ne $NL) {
            chomp($line);
            push(@headers, $line);
        }

        while ($line = <$client>) {
            chomp($line);
            push(@content, $line);
        }

        ($method, $path, $http_ver) = split(" ", $statusline);
    }

    @content = ("ab", "cd");
    my $content_txt = join($NL, @content) . $NL;
    @headers = ("Content-Length: " . length($content_txt), "Content-Type: text/html");

    print $client "HTTP/1.1 200 OK", $NL;
    print $client join($NL, @headers), $NL;
    print $client $NL;
    print $client $content_txt, $NL;
}

# /...  -> ./static/...
# /cgi/ -> perl ./cgi/...
