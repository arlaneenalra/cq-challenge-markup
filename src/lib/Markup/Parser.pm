package Markup::Parser;

use strict;

use fields qw/tokenizer/;

use base 'Markup::Base';

use Markup::Tree;

my %subdocument_node = map { $_ => 1 } qw/note/;

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
	    
	    ($not_done, $no_shift)=$self->_parse_eol($context,$tokens);

    	} elsif($token eq 'ORDERED_LIST'
		or $token eq 'UNORDERED_LIST') { # Handle various kinds of lists
	    
	    ($not_done, $no_shift)=$self->_parse_list($context, $tokens);
	    
	} elsif($token eq 'ESCAPE') { # Handle an escape token, 
	                              # this could mean any number of things
	    ($not_done, $no_shift)=$self->_parse_escape($context, $tokens);
	    
	} elsif($token eq 'TAG_BLOCK_END') {

	    # only append the node if there is something 
	    # to append
	    if(@{$context->text}) {
		$context->append_node();
	    }

	    $not_done='';
	    
	} elsif($token eq 'LINK_BLOCK_END') { # Handle link block ends

	    ($not_done, $no_shift)=$self->_parse_link_end($context, $tokens);

	} elsif($token eq 'LINK_MIDDLE') { 

	    ($not_done, $no_shift)=$self->_parse_link_middle($context, $tokens);

	} elsif($token eq 'LINK_BLOCK_START') { # Handle the start of a link
	    
	    ($not_done, $no_shift)=$self->_parse_link_start($context, $tokens, 'link');
	    
	} elsif($token eq 'LINK_DEF_START') { # Handle a url at the end of a link

	    ($not_done, $no_shift)=$self->_parse_link_start($context, $tokens, 'url');

	} elsif($token eq 'LINK_DEF_END') { # Handle the end of a link deinition
	    
	    ($not_done, $no_shift)=$self->_parse_link_def_end($context, $tokens);

	} elsif($token eq 'HEADER_TAG') { # Handle headers
	    
	    $self->_parse_header($context,$tokens);

	} elsif($token eq 'INDENT') { # Handle a block quote

	    ($not_done, $no_shift)=$self->_parse_indent($context, $tokens);
	    	    
	} elsif($token eq 'DEDENT') { # Handle list dedent
	    $not_done='';

	} elsif($token eq 'REMARK_LINK_DEF') { # Handle link_def ending
	    
	    # we replace the paragraph that was being built with
	    # a link_def
	    $context->append_node(
		Markup::Tree->new(
		    name => 'link_def',
		    indent => $context->indent,
		    inline => 0,
		    body => $context->text));
	    

	} else { # Catch all to be for use during implementation
	    warn "Unhandled token: $token";
	    $context->append_text($txt);
	}
	
	# move to the next token unless we are already there
	unless($no_shift) {
	    shift @$tokens;
	}
    }

    if(@{$context->text}) {
	$context->append_node();
    }

    return $context;
}

=head2 _parse_eol

Handles end of line/end of paragraph

=cut

sub _parse_eol {
    my ($self, $context, $tokens)=@_;

    my $not_done=1;
    my $no_shift='';

    my ($token, $txt)=@{$tokens->[0]};

    # are there any more tokens?
    if(@$tokens > 1) {

	# if we are at an end of line, convert it to a space
	$context->append_text(' ')
	    if($token eq 'END_OF_LINE');

	# if we are at the end of a paragraph, append a node
	$context->append_node()
	    if($token eq 'END_OF_PARAGRAPH'
	    and @{$context->text}); # make sure there is some text

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

    return ($not_done, $no_shift);
}



=head2 _parse_list

Handles aggregation of list items

=cut

sub _parse_list {
    my ($self, $context, $tokens)=@_;

    my ($token, $txt)=@{$tokens->[0]};

    # determine what kind of list item we have
    my $list_type=$token eq 'ORDERED_LIST' ? 'ol' : 'ul';

    # Are we already processing a list of this type ?
    if($context->name eq $list_type) {
	
	# process the list tag and start a new list item
	shift @{$tokens};
	
	$context->append_node(
	    $self->_parse_internal(
		Markup::Tree->new(
		    name => 'li',
		    indent => $context->indent),
		$tokens));

	return (1, '');
    }

    # this node should look like a block quote
    if($context->name ne 'blockquote') {
	warn 'Potentially bad state near ' . $context->text;
    }

    # replace the a blockquote node with the list we are currently parsing  
    $context->name=$list_type;
    $context->indent+=2;

    return (1, 1);
}

=head2 _parse_escape

Handles tagged markup and escaping via \

=cut
sub _parse_escape {
    my ($self, $context, $tokens)=@_;

    # move to the next token and take a look at them
    shift @$tokens;

    my ($token, $txt, $next_token, $next_txt)=
	(@{$tokens->[0]}, @{$tokens->[1]});

    # we have a normal escape here
    if($next_token ne 'TAG_BLOCK_START') {
	$context->append_text($txt);

	return (1, '');
    }
    
    # pop the next two tokens
    shift @$tokens;
    shift @$tokens;

    # start parsing the tagged text

    $context->append_text(
	$self->_parse_internal(
	  Markup::Tree->new(
	      name => $txt,
	      indent => $context->indent,
	      inline => !$subdocument_node{$txt},
	      subdocument => $subdocument_node{$txt}, # is this a subdocument node?
	    ),
	    $tokens));

    return (1, 1);
}

=head2 _parse_link_start

Handles the begining of a link block by converting it into an escape block

=cut

sub _parse_link_start {
    my ($self, $context, $tokens, $marker)=@_;
    

    # shift off the current token
    shift @$tokens;

    # replace it with an ESCAPE and TAG_BLOCK_START
    # this has to be done in reverse order to fit 
    # since unshift appends to the front of our array
    unshift @$tokens, ['TAG_BLOCK_START','{'];
    unshift @$tokens, ['', $marker];
    unshift @$tokens, ['ESCAPE',''];
    
    return (1,1);
}

=head2 _parse_link_middle

Handles linkes of the form [link|key]

=cut

sub _parse_link_middle {
    my ($self, $context, $tokens)=@_;

    my ($token, $txt)=@{$tokens->[0]};

    # only treat this as special if we are parsing a link
    if($context->name eq 'link') {
	$self->_parse_link_start($context, $tokens, 'key');

    } else {
	# we don't have a link, so fall back to text
	$tokens->[0]=['',$txt];
    }

    return (1, 1);
}
    

=head2 _parse_link_end 

Handles a link/key end by either converting it to a tag block end or
to a text block.

=cut

sub _parse_link_end {
    my ($self, $context, $tokens)=@_;

    my ($token, $txt)=@{$tokens->[0]};

    # are we ending a LINK_BLOCK with a key?
    if($context->name eq 'key') {
	
	# drop out of the key and reprocess in the next
	# layer up
	unshift @$tokens, ['', ''];
	return ('', 1);

    } elsif($context->name eq 'link') {
	# we have a link, so, convert this token into a tag block
	# ending
	$tokens->[0]=['TAG_BLOCK_END', '}'];

    } else {
	# we don't have a link or a key, so,
	# convert this block to text
	$tokens->[0]=['', $txt];

    }

    return (1, 1);
}

=head2 _parse_link_def_end

Handles "[link] <url>" style definitions.  When a LINK_DEF_END token is 
found it decides if the parent of the curren element should be converted 
into a link_def or if this token should be converted to a text token

=cut

sub _parse_link_def_end {
    my ($self, $context, $tokens)=@_;
    
    my ($token, $txt)=@{$tokens->[0]};
    my $not_done=1;

    # flag which indicates if we really have a link definition 
    # or something else
    my $real_link_def=1; 

    # we need to convert the enclosing paragraph into
    # a link_def element
    if(@$tokens>1) {
	my ($next_token, $next_txt)=@{$tokens->[1]};
	
	$real_link_def=($next_token eq 'END_OF_LINE'
			or $next_token eq 'END_OF_PARAGRAPH');
    }
    
    # if we have a real link, replace the paragraph we are in
    # with a link_def using a REMARK_LINK_DEF token

    if($real_link_def
	and $context->name eq 'url') {

	# pop the LINK_DEF_END token and replace it 
	shift @$tokens;
	unshift @$tokens, ['REMARK_LINK_DEF', 'link_def'];
	$not_done='';

    } else {
	# Convert this token to text
	$tokens->[0]=['', $txt];
    }

    use Data::Dumper;
    print &Dumper($tokens);
    
    return ($not_done, 1);
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
	    
	} elsif($token eq 'END_OF_LINE'
	    or $token eq 'END_OF_PARAGRAPH') {

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
    
    $context->append_node();

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

	# lists need to dedent twice
	if($context->name eq 'li'
	    and $diff < -2) {
	    
	    unshift @$tokens, ['DEDENT',$txt];
	    unshift @$tokens, ['DEDENT',$txt];
	}

	unshift @$tokens, ['',''];
	return ('','');
    }
}

=head2 _parse_header

Parses a chain of header '*' characters to into a header 

=cut

sub _parse_header {
    my ($self, $context, $tokens)=@_;
    
    my $no_shift='';
    
    my ($token, $txt)=@{$tokens->[0]};

    my $depth=split '\*', $txt; # track header depth
    $depth--; # headers have one space following them.

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
