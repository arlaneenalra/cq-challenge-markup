package Markup::Parser;

use strict;

use fields qw/tokenizer/;

use base 'Markup::Tokenizer';

=head1 NAME

Markupe::Parser - Base class for Markup parsers.

=head1 SYNOPSIS


=cut


=head1 METHODS


=head2 parse($content)

Accepts a scalar containing text and parses it into an internal parser tree.

TODO: Add a better description here

=cut

sub parse {
    my ($self, $content)=@_;
   
    # Normalize on a standard eol
    $content=$self->normalize($content);

    # Convert the content into a stream of tokens
    my @tokens=$self->tokenizer->tokenize($content);
    
    return \@tokens;
}


=head2 required_args
    
Returns an array of required arugments.

=cut

sub required_args {
    return qw/tokenizer/;
}

=head2 normalize

Converts end of line characters into the default for the platform markup.pl
is currently running on.

=cut

sub normalize {
    my ($self, $content)=@_;
    
    # match all four of the common eol markers
    $content=~s/\n|\r\n|\n\r|\r/$\//g;
    
    return $content;
}

1;
