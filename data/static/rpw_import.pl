use strict;
use warnings;

use File::Basename;

use lib dirname(__FILE__) . "/RPW";
use RPW;

use lib dirname(__FILE__) . "/RPW/ModYoink";
use ModYoink;

ModYoink::yoink_symbols("main", "RPW", [
    # RPW::Shell
    "spawn_read", "spawn_write", "escape_shell",

    # RPW::Text
    "printl", "escape_html_special",
    "uri_decode", "uri_encode",

    # RPW::HTTP
    "parse_url_params", "allowed_methods",
    "print_headers", "NL",

    # RPW: HTML
    "ea", "e", "set_title_script",
    "div_margins", "br",
]);

*text = \&escape_html_special;

1;
