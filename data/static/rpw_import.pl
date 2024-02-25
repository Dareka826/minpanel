use strict;
use warnings;

use lib "../static/rpw";

use RPW::Spawn;
use RPW::Text;
use RPW::HTTP;
use RPW::HTML;

BEGIN {
    *spawn_read   = \&RPW::Spawn::spawn_read;
    *spawn_write  = \&RPW::Spawn::spawn_write;
    *escape_shell = \&RPW::Spawn::escape_shell;

    *printl              = \&RPW::Text::printl;
    *escape_html_special = \&RPW::Text::escape_html_special;
    *uri_decode          = \&RPW::Text::uri_decode;
    *uri_encode          = \&RPW::Text::uri_encode;

    *parse_url_params = \&RPW::HTTP::parse_url_params;
    *allowed_methods  = \&RPW::HTTP::allowed_methods;
    *print_headers    = \&RPW::HTTP::print_headers;

    *ea               = \&RPW::HTML::ea;
    *e                = \&RPW::HTML::e;
    *set_title_script = \&RPW::HTML::set_title_script;
    *div_margins      = \&RPW::HTML::div_margins;
}

our $NL = $RPW::HTTP::NL;
our $br = $RPW::HTML::br;

1;
