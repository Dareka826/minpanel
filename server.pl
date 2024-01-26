#!/usr/bin/perl
use strict;
use warnings;

use Socket;
use Fcntl;

my $NL = "\r\n";

#### HTTP {{{

sub create_http_response {
    # {{{
    my ($code, $status, $headers_hashref, $content) = @_;
    my %headers = defined($headers_hashref) ? %$headers_hashref : ();

    my $ret = "HTTP/1.1 $code $status" . $NL;

    for my $key (keys(%headers)) {
        $ret = $ret . "$key: $headers{$key}" . $NL;
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

    while (defined($line = shift(@lines)) && $line ne "") {
        my ($key, $val) = split(/:\s*/, $line);
        $headers{$key} = $val;
    }
    while (defined($line = shift(@lines)) && $line ne "") {
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

#### }}}

#### Sockets {{{

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

sub set_nonblock {
    # {{{
    my ($fh) = @_;

    my $flags = fcntl($fh, F_GETFL, 0);
    fcntl($fh, F_SETFL, $flags | O_NONBLOCK);
} # }}}

sub set_block {
    # {{{
    my ($fh) = @_;

    my $flags = fcntl($fh, F_GETFL, 0);
    fcntl($fh, F_SETFL, $flags & (~O_NONBLOCK));
} # }}}

sub wait_read_timeout {
    # {{{
    my ($fh, $timeout) = @_;

    my $readbits_in = '';
    vec($readbits_in, fileno($fh), 1) = 1;

    select(my $readbits_out = $readbits_in, undef, undef, $timeout);

    if ($readbits_in ne $readbits_out) {
        return 0;
    }
    return 1;
} # }}}

#### }}}

my $socket_fh = mk_server_socket("127.0.0.1", 8000, 10);
print "Server started\n";

for (my $packed_addr; $packed_addr = accept(my $client, $socket_fh); close $client) {
    my ($port, $addr) = sockaddr_in($packed_addr);

    print("connection from ", inet_ntoa($addr), "\n");

    # Wait for data
    set_nonblock($client);
    if (wait_read_timeout($client, 3) == 0) {
        print "connection timed out.\n";
        next;
    }

    # Handle request
    my %request;
    {
        local $/;
        %request = %{parse_http_request(<$client>)};
    }

    my $path = $request{"path"};
    if ($path =~ m/\/$/) {
        $path = $path . "index.html";
    }

    if ($path !~ m/^\/cgi\//) {
        # Static content
        if ($request{"method"} ne "GET") {
            print $client create_http_response(
                400, "Bad Request"
            );
            next;
        }

        my $fh;
        if (!defined(open($fh, "<", "./static/$path"))) {
            print $client create_http_response(
                404, "Not Found"
            );
            next;
        }

        my $data = "";
        while (my $line = <$fh>) {
            $data = $data . "$line$NL";
        }

        close($fh);

        print $client create_http_response(
            200, "OK",
            { "Content-Length" => length($data) },
            $data
        );
        next;
    }

    my @content = ("ab", "cd");
    my $content_txt = join($NL, @content) . $NL;

    my $res = create_http_response(
        200, "OK",
        {
            "Content-Length" => length($content_txt),
            "Content-Type" => "text/html",
        },
        $content_txt
    );
    print $client $res;
}

# /...  -> ./static/...
# /cgi/ -> perl ./cgi/...
