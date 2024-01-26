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

print("<span>Hello from content script!</span><br/><span>Current time: $time</span>");
