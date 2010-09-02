package Markup::Parser;

use strict;

use fields qw/tokenizer/;

use base 'Markup::Tokenizer';

=head1 NAME

Markupe::Parser - Base class for Markup parsers.

=head1 SYNOPSIS


=cut


=head1 METHODS

=head1 required_args
    
Returns an array of required arugments.

=cut

sub required_args {
    return qw/tokenizer/;
}

1;
