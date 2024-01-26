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

my $time;
{
    (my $err, $time) = @{spawn_read("date '+%Y-%m-%d %H:%M:%S'")};
    if ($err != 0) {
        $time = "ERR";
    }
    chomp($time);
}

sub header_html {
    return <<"EOF";
    <div id="header-left">
        <span>MinPanel</span>
    </div>
    <div id="header-center">
    </div>
    <div id="header-right">
        <span>$time</span>
    </div>
EOF
}

print( header_html() );
