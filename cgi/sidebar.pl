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

print("Hello from sidebar script!");
