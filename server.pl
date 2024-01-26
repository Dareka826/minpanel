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

my %_mime_types = (
    "css" => "text/css",
    "html" => "text/html",
    "js" => "text/javascript",
);

sub get_mime_type {
    # {{{
    my ($ext) = @_;

    for my $key (keys(%_mime_types)) {
        if ($ext eq $key) {
            return $_mime_types{$key};
        }
    }

    return undef;
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

#### CGI {{{

sub spawn_read {
    # {{{
    my ($command) = @_;

    my $fh;
    if (!defined(open($fh, "-|", $command))) {
        return "";
    }

    local $/;
    my $output = <$fh>;

    close($fh);

    return $output;
} # }}}

sub spawn_write {
    # {{{
    my ($command, $input) = @_;
    if (!defined($input)) { $input = ""; }

    my $fh;
    if (!defined(open($fh, "|-", $command))) {
        return "";
    }

    print $fh $input;

    close($fh);
} # }}}

sub esc_quotes {
    my ($str) = @_;
    $str =~ s/'/\\''\\'/;
    return $str;
}

sub run_cgi_script {
    my ($method, $path, $content) = @_;
    my $fh;

    # mktemp
    # write to temp file
    # run cgi script with input from temp file and record its output and exit code
    open($fh, "-|", 'mktemp "${TMPDIR:-/tmp}/minpanel.cgi.XXXXX"');
    my $tmpfile = <$fh>;
    chomp($tmpfile);
    close($fh);

    print($tmpfile, "\n");

    open($fh, "-|", "rm '" . esc_quotes($tmpfile) . "'");
    close($fh);
}

run_cgi_script();
exit(0);

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

    print("[" . $request{"method"} . "] $path\n");

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

        my $ext = $path;
        $ext =~ s/^.*\.//;

        print $client create_http_response(
            200, "OK",
            {
                "Content-Type" => get_mime_type($ext) or "text/plain",
                "Content-Length" => length($data),
            },
            $data
        );
        next;
    }
    # else

    # Run CGI script
}

# /...  -> ./static/...
# /cgi/ -> perl ./cgi/...
