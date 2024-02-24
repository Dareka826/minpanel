our $NL = "\r\n";

require '../static/spawn.pl';

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

sub set_title {
    my ($title) = @_;

    return <<"EOF";
<script type="text/javascript">
    if (document.querySelector("head > title") === null) {
        let t = document.createElement("title");
        document.head.appendChild(t);
    }

    document.querySelector("head > title").innerHTML = '$title';
</script>
EOF
}

1;
