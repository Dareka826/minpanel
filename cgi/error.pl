#!/usr/bin/perl
use strict;
use warnings;

require './priv/common.pl';
our $NL;

my $method;
my $path;
{
    local $/ = $NL;
    $method = <>;
    $path = <>;
}

my $input;
{
    local $/;
    $input = <>;
}

my %params = %{parse_url_params($path)};
### BEGIN CGI CODE

if (!exists($params{"error"}) && !exists($params{"text"})) {
    $params{"text"} = "No Error";
}

sub error_html {
    my ($code, $message) = @_;
    my $html = "";

    if (defined($code)) {
        $code = escape_html_special($code);
        $html = $html . "<div id=\"error-text\">Error $code</div>";

        if (defined($message)) {
            $html = $html . "<br/>";
        }
    }

    if (defined($message)) {
        $message = escape_html_special($message);
        $html = $html . "<div id=\"error-message\">$message</div>";
    }

    return <<"EOF";
    <div class="center-box-outer">
        <div class="center-box-inner" id="error-box">
            $html
        </div>
    </div>
EOF
}

print(
    html_doc(
        html_head("MinPanel - Error"),
        error_html($params{"error"}, $params{"text"})
    )
);
