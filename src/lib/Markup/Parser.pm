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


    my $not_done=1; # set to true if we need to return to a parent
    
    # handle various tokens
    while(@$tokens && $not_done) {
	my ($token, $txt)=@{$tokens->[0]};
	print "$token => $txt$/";

	my $no_shift=''; # set to true if a shift is not needed

	# TODO: this might be better handled as a hash

	if($token eq '') { # Handle simple text
	    $context->append_text($txt);

	} elsif($token eq 'END_OF_LINE') { # Handle a single eol 
	    
	    # Don't append a space if there are no more tags after
	    # this one.
	    if(@$tokens >1) {
		$context->append_text(' ');
	    } else {
		$context->append_node();
	    }
	    
	} elsif($token eq 'END_OF_PARAGRAPH') { # Handle the end of a node
	    $context->append_node();

    	} elsif($token eq 'ESCAPE') { # Handle an escape token, 
	                              # this could mean any number of things
	    $self->_parse_escape($context, @$tokens);

	} elsif($token eq 'HEADER_TAG' or
	    $token eq 'HEADER_END') { # Handle headers
	    
	    $no_shift=$self->_parse_header($context,$tokens);

	} elsif($token eq '2SPACE'
	    or $token eq '3SPACE') { # Handle a block quote
	    
	    ($not_done, $no_shift)=$self->_parse_indent($context, $tokens);
	    
	    # # recurse to handle the blockquote 
	    # $context->append_node(
	    # 	$self->_parse_internal(
	    # 	    Markup::Tree->new(
	    # 		name => 'blockquote',
	    # 		indent => $context->indent+2),
	    # 	    $tokens));
	    
	} else { # Catch all to be for use during implementation
	    warn "Unhandled token: $token";
	}
	
	# move to the next token unless we are already there
	shift @$tokens
	    unless $no_shift;
    }

    # do a final append for the given node
    #$context->append_node();

    return $context;
}

=head2 _parse_indent

Checks to see what indentation level we are currently at
and takes appropriate action.  Returns a list of values,
the first being if we are done yet and the second indicating
if the parent parser needs to move to another token or not.

=cut

#TODO: Space handling will need to be reworked heavily

sub _parse_indent {
    my ($self, $context, $tokens)=@_;

    # count the number of spaces we have here
    my $count=0;
    my ($token, $txt)=@{$tokens->[0]};
    while($token eq '2SPACE'
	  or $token eq '3SPACE') {
	
	# increment the count correctly
	$count+=2
	    if($token eq '2SPACE');

	$count+=3
	    if($token eq '3SPACE');

	# move to the next token
	shift @$tokens;
	($token, $txt)=@{$tokens->[0]};
    }
    
    my $diff=$count - $context->indent;

    # do we have a new indentation level?
    if(!$diff) {
	print "HERE";
	# we are at the same indent level, do nothing
	return (1,1);

    } elsif($diff > 0) {
	# we are at a new indention level, do we have a blockquote 
	# or verbatim?


	if($diff == 2) {
	    # blockquote
    	    $context->append_node(
	    	$self->_parse_internal(
	    	    Markup::Tree->new(
	    		name => 'blockquote',
	    		indent => $context->indent+2),
	    	    $tokens));
	    return (1,'');

	} elsif($diff >= 3) {
	    # verbatim
    	    $context->append_node(
	    	$self->_parse_internal(
	    	    Markup::Tree->new(
	    		name => 'verbatim',
	    		indent => $context->indent+3),
		    $tokens));
	    return (1,'');
	} else {
	    return ('','');
	}
    }
}

=head2 _parse_header

parses a chain of header '*' characters 

=cut

sub _parse_header {
    my ($self, $context, $tokens)=@_;
    
    my $depth=1; # track header depth
    my $no_shift='';
    
    my ($token, $txt)=@{$tokens->[0]};
    # figure out how deep a header we have
    while($token eq 'HEADER_TAG') {
	$depth++;

	# move to the next tag
	shift @$tokens;
	($token, $txt)=@{$tokens->[0]};	
    }

    # do we have a valid header end tag?
    if($token ne 'HEADER_END') {
	warn "Bad $depth deep header near $token token containing '$txt'";

	$no_shift=1; # attempt to keep going

	$depth--; # we assume the HEADER_END up front
    }

    $context->node="h$depth";
    
    return $no_shift;
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
