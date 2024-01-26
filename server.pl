#!/usr/bin/perl
use strict;
use warnings;

use Socket;
use Fcntl;
use IO::Poll;

my $NL = "\r\n";

#### HTTP {{{

sub create_http_response {
    # {{{
    my ($code, $status, $headers_hashref, $content) = @_;
    my %headers = defined($headers_hashref) ? %$headers_hashref : ();

    if (!defined($code)) {
        print("[W]: No response code, setting 500\n");
        warn("\$code = undef");

        $code = 500;
        $status = "Internal server error";
        %headers = ();
        $content = "";

    } elsif(!defined($status)) {
        $status = "";
    }

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

    if (!defined($method) || !defined($path) || !defined($http_ver)) {
        print("[W]: Invalid HTTP status line\n");
        warn "Invalid HTTP status line";
        return undef;
    }

    if ($http_ver ne "HTTP/1.1") {
        print("[W]: Unsupported HTTP version: $http_ver\n");
        warn("Unsupported HTTP version: $http_ver");
        return undef;
    }

    my %headers = ();
    my $content = "";

    while (defined($line = shift(@lines)) && $line ne "") {
        my ($key, $val) = split(/:\s*/, $line);
        $headers{$key} = $val;
    }
    while (defined($line = shift(@lines)) && $line ne "") {
        $content = $content . $line . $NL;
    }

    return {
        "http_ver" => $http_ver,
        "method" => $method,
        "path" => $path,
        "headers" => \%headers,
        "content" => $content,
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

    my $flags = fcntl($fh, F_GETFL, 0)
        || return [1, "fcntl get: $!"];

    fcntl($fh, F_SETFL, $flags | O_NONBLOCK)
        || return [1, "fcntl set: $!"];

    return [0, undef];
} # }}}

sub set_block {
    # {{{
    my ($fh) = @_;

    my $flags = fcntl($fh, F_GETFL, 0)
        || return [1, "fcntl get: $!"];

    fcntl($fh, F_SETFL, $flags & (~O_NONBLOCK))
        || return [1, "fcntl set: $!"];

    return [0, undef];
} # }}}

sub wait_read_timeout {
    # {{{
    my ($fh, $timeout) = @_;

    my $poll_data = IO::Poll::new();
    IO::Poll::mask($poll_data, $fh, IO::Poll::POLLIN);

    my $ev_count = IO::Poll::poll($poll_data, $timeout);

    if ($ev_count < 1) {
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
        return [1, ""];
    }

    local $/;
    my $output = <$fh>;

    close($fh);
    return [0, $output];
} # }}}

sub spawn_write {
    # {{{
    my ($command, $input) = @_;
    if (!defined($input)) { $input = ""; }

    my $fh;
    if (!defined(open($fh, "|-", $command))) {
        return 1;
    }

    print $fh $input;

    close($fh);
    return 0;
} # }}}

sub esc_quotes {
    my ($str) = @_;
    $str =~ s/'/\\''\\'/;
    return $str;
}

sub run_cgi_script {
    my ($method, $path, $content) = @_;
    my $fh;
    my $err;
    my $ign;
    if (!defined($content)) { $content = ""; }

    if ($path !~ m/^\/cgi\//) {
        print("not /cgi folder!\n");
        return [1, ""];
    }

    # Convert to fs path
    my $cgi_script_path = "." . $path;
    $cgi_script_path =~ s/\/([^\/]+)\?[^\/]*$/\/$1/; # Strip path params
    $cgi_script_path = $cgi_script_path . ".pl"; # Append perl extension

    # Check if such a path exists
    ($err, my $cgi_exists) = @{spawn_read("[ -e '" . esc_quotes($cgi_script_path) . "' ]; printf '%s\\n' \"\$?\"")};

    if ($err == 1) {
        return [1, "script error"];
    } else {
        chomp($cgi_exists);
        if ($cgi_exists ne "0") {
            return [1, "no such script"];
        }
    }

    # run cgi script with input from temp file and record its output and exit code
    ($err, my $tmpfile) = @{spawn_read('mktemp "${TMPDIR:-/tmp}/minpanel.cgi.XXXXX"')};
    if ($err == 1) {
        return [1, "mktemp failed"];
    }

    chomp($tmpfile);

    $err = spawn_write("cat >'" . esc_quotes($tmpfile) . "'", $method . $NL . $path . $NL . $content);
    if ($err == 1) {
        return [1, "cat failed"];
    }

    ($err, my $data) = @{spawn_read("perl '" . esc_quotes($cgi_script_path) . "' <'" . esc_quotes($tmpfile) . "'")};
    if ($err == 1) {
        return [1, "cgi script failed"];
    }

    ($err, $ign) = @{spawn_read("rm '" . esc_quotes($tmpfile) . "'")};
    if ($err == 1) {
        return [1, "rm failed"];
    }

    return [0, $data];
}

#### }}}

my $socket_fh = mk_server_socket("127.0.0.1", 8000, 10);
print "Server started\n";

for (my $packed_addr; $packed_addr = accept(my $client, $socket_fh); close $client) {
    my ($port, $addr) = sockaddr_in($packed_addr);

    print("connection from ", inet_ntoa($addr), "\n");

    # Wait for data
    my ($err, $str) = @{set_nonblock($client)};
    if ($err != 0) {
        print("[E]: set_nonblock: $str");
        next;
    }
    undef $err;
    undef $str;

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

    print("[" . $request{"method"} . "] $path\n");

    if ($path !~ m/^\/cgi\//) {
        # Static content
        if ($path =~ m/\/$/) {
            $path = $path . "index.html";
        }

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
                "Content-Type" => (get_mime_type($ext) or "text/plain"),
                "Content-Length" => length($data),
            },
            $data
        );
        next;
    }
    # else

    # Run CGI script
    {
        my ($err, $data) = @{run_cgi_script($request{"method"}, $path, $request{"content"})};

        if ($err != 0) {
            if ($request{"method"} ne "GET") {
                print $client create_http_response(
                    500, "Internal server error"
                );
                next;
            }
        }

        print $client create_http_response(
            200, "OK",
            {
                "Content-Type" => "text/html",
                "Content-Length" => length($data),
            },
            $data
        );
    }
}

# /...  -> ./static/...
# /cgi/ -> perl ./cgi/...
