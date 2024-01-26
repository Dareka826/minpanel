our $NL = "\r\n";

require './priv/spawn.pl';

sub escape_html_special {
    my ($str) = @_;

    $str =~ s/"/&#34;/g;
    $str =~ s/'/&#39;/g;
    $str =~ s/&/&#38;/g;
    $str =~ s/</&#60;/g;
    $str =~ s/>/&#62;/g;

    return $str;
}

sub uri_decode {
    my ($str) = @_;

    my $idx = index($str, "%");
    my @indices;

    my $new_str = "";

    while ($idx != -1) {
        push(@indices, $idx);

        my $code = substr($str, $idx+1, 2);
        $new_str = $new_str . substr($str, 0, $idx) . chr(hex($code));
        $str = substr($str, $idx+3);

        $idx = index($str, "%");
    }

    if (length($str) > 0) {
        $new_str = $new_str . $str;
    }

    return $new_str;
}

sub html_doc {
    my ($head, $body) = @_;

    return <<"EOF";
    <!DOCTYPE HTML>
    <html>
        <head>
            $head
        </head>
        <body>
            $body
        </body>
    </html>
EOF
}

sub html_head {
    my ($title) = @_;
    my $title_esc = escape_html_special($title);

    return <<"EOF";
    <title>$title_esc</title>
    <script src="/htmx.min.js"></script>
    <link rel="stylesheet" type="text/css" href="/style.css"/>
EOF
}

sub parse_url_params {
    my ($path) = @_;

    $path =~ s/\n+$//;
    $path =~ s/^[^?]*\?//;
    my @params_arr = split(/&/, $path);

    my %params;
    for $param (@params_arr) {
        my ($key, $val) = split(/=/, $param, 2);
        $params{$key} = uri_decode($val);
    }

    return \%params;
}

1;
