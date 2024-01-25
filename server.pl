#!/usr/bin/perl
use strict;
use warnings;

use Socket;
use Fcntl;

my $NL = "\r\n";

sub create_http_response {
    # {{{
    my ($code, $status, $headers_ref, $content) = @_;
    my @headers = @$headers_ref;

    my $ret = "HTTP/1.1 $code $status" . $NL;

    if (scalar(@headers) > 0) {
        $ret = $ret . join($NL, @headers) . $NL;
    }

    $ret = $ret . $NL;

    if (defined($content)) {
        $ret = $ret . $content . $NL;
    }

    return $ret;
} # }}}

sub parse_http_request {
    # {{{
    my ($data) = @_;
    my @lines = split(quotemeta($NL), $data);
    my $line;

    my ($method, $path, $http_ver) = split(/ /, shift(@lines));
    my %headers;
    my @content;

    while (defined($line = shift @lines) && $line ne "") {
        my ($key, $val) = split(/:\s*/, $line);
        $headers{$key} = $val;
    }
    while (defined($line = shift @lines) && $line ne "") {
        push(@content, $line);
    }

    return {
        "http_ver" => $http_ver,
        "method" => $method,
        "path" => $path,
        "headers" => \%headers,
        "content" => \@content,
    };
} # }}}

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

    my %request;
    {
        local $/;
        %request = %{parse_http_request(<$client>)};
    }

    my @content = ("ab", "cd");
    my $content_txt = join($NL, @content) . $NL;

    my $res = create_http_response(
        200, "OK",
        [
            "Content-Length: " . length($content_txt),
            "Content-Type: text/html",
        ],
        $content_txt
    );
    print $client $res;
}

# /...  -> ./static/...
# /cgi/ -> perl ./cgi/...
