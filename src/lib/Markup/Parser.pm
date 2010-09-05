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
    while(@$tokens and $not_done) {
	my ($token, $txt)=@{$tokens->[0]};

	my $no_shift=''; # set to true if a shift is not needed

	# TODO: this might be better handled as a hash

	if($token eq '') { # Handle simple text
	    $context->append_text($txt);

	} elsif($token eq 'END_OF_LINE'
	    or $token eq 'END_OF_PARAGRAPH') { # Handle a single eol 

	    # are there any more tokens?
	    if(@$tokens >1) {

		# if we are at an end of line, convert it to a space
		$context->append_text(' ')
		    if($token eq 'END_OF_LINE');

		# if we are at the end of a paragraph, append a node
		$context->append_node()
		    if($token eq 'END_OF_PARAGRAPH');

		# move to the next line
		shift @$tokens;

                # check indent on end of line
		if($context->indent) {
		    ($not_done, $no_shift)=$self->_parse_indent($context, $tokens);

		} else {
		    # we have already shifted once
		    $no_shift=1;
		}
		
	    } else {
		# if we are the last token, close out whatever 
		# node we were working on
		$context->append_node();
	    }

    	} elsif($token eq 'ORDERED_LIST'
		or $token eq 'UNORDERED_LIST') { # Handle various kinds of lists
	    
	    $self->_parse_list($context, $tokens);

	    $no_shift=1;
	    #$not_done='';
	    
	} elsif($token eq 'ESCAPE') { # Handle an escape token, 
	                              # this could mean any number of things
	    $self->_parse_escape($context, $tokens);

	} elsif($token eq 'HEADER_TAG' or
	    $token eq 'HEADER_END') { # Handle headers
	    
	    $no_shift=$self->_parse_header($context,$tokens);

	} elsif($token eq 'INDENT') { # Handle a block quote

	    ($not_done, $no_shift)=$self->_parse_indent($context, $tokens);
	    	    
	} else { # Catch all to be for use during implementation
	    warn "Unhandled token: $token";
	}
	
	# move to the next token unless we are already there
	unless($no_shift) {
	    shift @$tokens;
	}
    }

    return $context;
}

=head2 _parse_list

Handles aggregation of list items

=cut

sub _parse_list {
    my ($self, $context, $tokens)=@_;

    my ($token, $tst)=@{$tokens->[0]};

    # determine what kind of list item we have
    my $list_type=$token eq 'ORDERED_LIST' ? 'ol' : 'ul';

    # Are we already processing a list of this type ?
    if($context->name eq $list_type) {
	print "LI " . $context->indent . $/;
	
	# process the list tag and start a new list item
	shift @{$tokens};
	
	$context->append_node(
	    $self->_parse_internal(
		Markup::Tree->new(
		    name => 'li',
		    indent => $context->indent+4),
		$tokens));

	return;
    }

    # # we are not processing a list, time to start one
    # $context->append_node(
    # 	$self->_parse_internal(
    # 	    Markup::Tree->new(
    # 		name => $list_type, # properly tag the list
    # 		indent => $context->indent),
    # 	    $tokens));
    
    if($context->name eq 'blockquote') {
	$context->name=$list_type;
    }
}


=head2 _parse_verbatim

Handle verbatim blocks

=cut

sub _parse_verbatim {
    my ($self, $context, $tokens)=@_;

    # If we have no more tokens, return the tree as it
    # currently exists
    return $context
	unless @$tokens;


    my $not_done=1; # set to true if we need to return to a parent
    
    # handle various tokens
    while(@$tokens and $not_done) {
	my ($token, $txt)=@{$tokens->[0]};

	my $no_shift=''; # set to true if a shift is not needed

	# TODO: this might be better handled as a hash

	if($token eq 'INDENT') { # Handle a block quote
	    ($not_done, $no_shift)=$self->_parse_indent($context, $tokens);
	    
	} elsif($token eq 'END_OF_LINE') {

	    if(@$tokens>1) {

		shift @$tokens;

		# parse the next object and see if we have a decrease in indentation
		($not_done, $no_shift)=$self->_parse_indent($context, $tokens);
		
		# a not done here means we are at the same indentation
		# level
		if($not_done) {
		    $context->append_text($txt);
		}
	    }

	} else {

	    $context->append_text($txt);
	}
	
	unless($no_shift) {
	    shift @$tokens;
	}
    }

    return $context;
}


=head2 _parse_indent

Checks to see what indentation level we are currently at
and takes appropriate action.  Returns a list of values,
the first being if we are done yet and the second indicating
if the parent parser needs to move to another token or not.

=cut

sub _parse_indent {
    my ($self, $context, $tokens)=@_;

    # count the number of spaces we have here
    my ($token, $txt)=@{$tokens->[0]};
    my $count=length $txt;

    # make sure we are looking at an indent token
    if($token ne 'INDENT') {
	$count=0;
    }

    # how different than the current indention are we?
    my $diff=$count - $context->indent;


    # do we have a new indentation level?
    if($diff == 0) {
	# we are at the same indent level, do nothing
	return (1,'');

    } elsif($diff > 0) {
	# are we already parsing a verbatim block?
	if($context->verbatim) {
	    # set this token to a text token and 
	    # plug in the number of spaces minus current indention level
	    @{$tokens->[0]}=('', ' ' x $diff);
	    return (1,1);
	}

	# do we have a blockquote or verbatim?

	if($diff == 2) {
	    # blockquote
    	    $context->append_node(
	    	$self->_parse_internal(
	    	    Markup::Tree->new(
	    		name => 'blockquote',
	    		indent => $context->indent+2),
	    	    $tokens));
	    return (1,1);

	} elsif($diff >= 3) {
	    # replace the current token with a text token
	    @{$tokens->[0]}=('',' ' x ($diff-3));
	    
	    # verbatim
    	    $context->append_node(
	    	$self->_parse_verbatim(
	    	    Markup::Tree->new(
	    		name => 'pre',
	    		indent => $context->indent+3,
			verbatim => 1),
		    $tokens));
	    return (1,1);
	}
    } else { # moving back up an indention level
	
	# no_shift won't propgate to parent scope
	# so we do this to avoid getting shifted
	unshift @$tokens, ['','']; 
	return ('','');
    }
}

=head2 _parse_header

Parses a chain of header '*' characters to into a header 

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
