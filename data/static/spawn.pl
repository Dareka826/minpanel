use strict;
use warnings;

sub spawn_read {
    my ($command) = @_;

    my $fh;
    if (!defined(open($fh, "-|", $command))) {
        return [1, undef];
    }

    my $output;
    {
        local $/;
        $output = <$fh>;
    }

    close($fh) || warn "close: $!";
    return [0, $output];
}

sub spawn_write {
    my ($command, $input) = @_;
    if (!defined($input)) { $input = ""; }

    my $fh;
    if (!defined(open($fh, "|-", $command))) {
        return 1;
    }

    print $fh $input;

    close($fh) || warn "close: $!";
    return 0;
}

sub esc_quotes {
    my ($str) = @_;
    $str =~ s/'/\\''\\'/;
    return $str;
}

1;
