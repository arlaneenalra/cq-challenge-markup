package Markup::Parser;

use strict;

use fields qw/tokenizer/;

use base 'Markup::Base';

use Markup::Tree;

=head1 NAME

Markup::Parser - Base class for Markup parsers.

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

    use Data::Dumper;
    print &Dumper(\@tokens);

    # Parse our token stream
    return $self->_parse_internal(Markup::Tree->new(), \@tokens);
}

=head2 _parse_internal

A recursive function that is used by the parser to convert a token list 
into a tree form.

=cut

sub _parse_internal {
    my ($self, $context, $tokens)=@_;

    # If we have no more tokens, return the tree as it
    # currently exists
    return $context
	unless @$tokens;
    
    # handle various tokens
    while(@$tokens) {
	my ($token, $txt)=@{$tokens->[0]};

	# TODO: this might be better handled as a hash

	if($token eq '') { # Handle simple text
	    $context->append_text($txt);

	} elsif($token eq 'END_OF_LINE') { # Handle a single eol 
	    
	    # Don't append a space if there are no more tags after
	    # this one.
	    if(@$tokens >1) {
		$context->append_text(' ');
	    }
	    
	} elsif($token eq 'END_OF_PARAGRAPH') { # Handle the end of a node
	    $context->append_node();
	    
	} else { # Catch all to be for use during implementation
	    warn "Unhandled token: $token";
	}
	
	# move to the next token
	shift @$tokens;
    }

    # do a final append for the given node
    $context->append_node();

    return $context;
    
}

=head2 required_args
    
Returns an array of required constructor arugments.

=cut

sub required_args {
    return qw/tokenizer/;
}

=head2 normalize

Converts end of line characters and tabs into a values expected buy the tokenizer
=cut

sub normalize {
    my ($self, $content)=@_;
    
    # match all four of the common eol markers
    $content=~s/\n|\r\n|\n\r|\r/$\//g;

    # Convert tabs into spaces
    $content=~s/\t/        /g;
    
    return $content;
}

1;
