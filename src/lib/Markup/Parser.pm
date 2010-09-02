package Markup::Parser;

use fields qw//;

# Definition of the various tokens 
my @token_patterns=(
    [qr(\*) => 'HEADER_TAG'], # Matches '*' which is used to indicate a header

    # TODO:  Add link processing

    [qr(\\) => 'TAG_START'], # Match the escape character
    [qr({) => 'TAG_BLOCK_START'], # Match the start of the a tag block
    [qr(}) => 'TAG_BLOCK_END'], # Match the end of a tag block

    # [qr(\[) => 'LINK_BLOCK_START'], # Match the start of a link block
    # [qr(\|) => 'LINK_MIDDLE'], # Match middle of a link block
    # [qr(\]) => 'LINK_BLOCK_END'], # Match the end of a link block

    
    [qr(  -) => 'UNORDER_LIST'], # Matches an unordered list
    [qr(  #) => 'ORDER_LIST'], # Matches an ordered list
    
    [qr(   ) => '3SPACE'], # Matches leading whitespace
    [qr(  ) => '2SPACE'], # Matches leading whitespace
    
    [qr($/\s*$/) => 'END_OF_PARAGRAPH'], # Matches an end of paragraph marker
    [qr($/) => 'END_OF_LINE'], # Matches an end of line marker
    );


=head1 NAME

Markupe::Parser - Base class for Markup parsers.

=head1 SYNOPSIS


=cut

1;
