our $NL = "\r\n";

require '../static/spawn.pl';

sub printl {
    for my $arg (@_) {
        print($arg);
    }
    print("\n");
}

sub escape_html_special {
    my ($str) = @_;

    $str =~ s/"/&#34;/g;
    $str =~ s/'/&#39;/g;
    $str =~ s/&/&#38;/g;
    $str =~ s/</&#60;/g;
    $str =~ s/>/&#62;/g;

    return $str;
}
*text = \&escape_html_special;

sub escape_spaces {
    my ($str) = @_;
    $str =~ s/ /\&nbsp;/g;
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
    $title = escape_html_special($title);

    return <<"EOF";
<script id="set-title-script" type="text/javascript">
    // Add title element if missing
    if (document.querySelector("head > title") === null) {
        let t = document.createElement("title");
        document.head.appendChild(t);
    }

    // Set title content
    document.querySelector("head > title").innerHTML = '$title';

    // Remove this script tag
    let me = document.querySelector("#set-title-script");
    me.parentElement.removeChild(me);
</script>
EOF
}

sub allowed_methods {
    my ($arrref_methods) = @_;
    my @methods = @{$arrref_methods};
    my $env_method = $ENV{"REQUEST_METHOD"};

    for my $method (@methods) {
        if ($method eq $env_method) {
            return;
        }
    }
    exit(1);
}

sub ea {
    my ($tag, $attributes_hashref, $content) = @_;

    # attributes hash to text
    my $attributes_txt = "";
    if (defined($attributes_hashref)) {
        my %attributes = %{$attributes_hashref};

        for my $attr (keys %attributes) {
            my $val = $attributes{$attr};

            if (!defined($val)) {
                $attributes_txt = $attributes_txt . " $attr";
                next;
            }

            $val =~ s/"/\\"/g;
            $attributes_txt = $attributes_txt . " $attr=\"$val\"";
        }
    }

    if (!defined($content)) {
        return "<$tag$attributes_txt/>";
    }
    return "<$tag$attributes_txt>$content</$tag>";
}

sub e {
    my ($tag, $content) = @_;
    return ea($tag, undef, $content);
}

sub print_headers {
    my ($headers_hashref) = @_;
    if (!defined($headers_hashref)) { return; }

    my %headers = %{$headers_hashref};
    for my $key (keys %headers) {
        my $val = $headers{$key};

        printl("$key: $val");
    }
    printl();
}

sub div_margins {
    my ($left_classes, $top_classes, $right_classes, $bottom_classes, $content) = @_;

    return ea(
        "div", {
            "class" => "div-margin-horizontal-container",
        }, ea(
            "div", {
                "class" => "div-margin-horizontal $left_classes",
            }, ""
        ) . ea(
            "div", {
                "class" => "div-margin-vertical-container",
            }, ea(
                "div", {
                    "class" => "div-margin-vertical $top_classes",
                }, ""
            ) . ea(
                "div", {
                    "class" => "div-margin-content",
                },
                $content
            ) . ea(
                "div", {
                    "class" => "div-margin-vertical $bottom_classes",
                }, ""
            )
        ) . ea(
            "div", {
                "class" => "div-margin-horizontal $right_classes",
            }, ""
        )
    );
}

our $br = e("br", undef);

1;
