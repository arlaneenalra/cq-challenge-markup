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
	    
	    $no_shift=$self->_parse_list($context, $tokens);
	    
	} elsif($token eq 'ESCAPE') { # Handle an escape token, 
	                              # this could mean any number of things
	    $no_shift=$self->_parse_escape($context, $tokens);
	    
	} elsif($token eq 'TAG_BLOCK_END') {

	    # only append the node if there is something 
	    # to append
	    if(@{$context->text}) {
		$context->append_node();
	    }

	    $not_done='';
	    
	} elsif($token eq 'LINK_BLOCK_END') { # Handle link block ends

	    # are we ending a LINK_BLOCK with a key?
	    if($context->name eq 'key') {
		
		# drop out of the key and reprocess in the next
		# layer up
		unshift @$tokens, ['', ''];
		$not_done='';

	    } elsif($context->name eq 'link') {
		# we have a link, so, convert this token into a tag block
		# ending
		$tokens->[0]=['TAG_BLOCK_END', '}'];

	    } else {
		# we don't have a link or a tag, so,
		# convert this block to text
		$tokens->[0]=['', $txt];

	    }

	    $no_shift=1;

	} elsif($token eq 'LINK_DEF_END') { # Handle the end of a link deinition
	    
	    my $real_link_def=1;

	    # we need to convert the enclosing paragraph into
	    # a link_def element
	    if(@$tokens>1) {
		my ($next_token, $next_txt)=@{$tokens->[1]};
		
		$real_link_def=($next_token eq 'END_OF_LINE'
				or $next_token eq 'END_OF_PARAGRAPH');
	    }
	    
	    # if we have a real link, replace the paragraph we are in
	    # with a link def
	    if($real_link_def) {
		shift @$tokens;
		unshift @$tokens, ['REMARK_LINK_DEF', 'link_def'];
		$not_done='';

	    } else {
		# Convert this token to text
		$tokens->[0]=['', $txt];
	    }
	    
	    $no_shift=1;

	} elsif($token eq 'LINK_BLOCK_START') { # Handle links
	    $self->_parse_link_start($context, $tokens, 'link');
	    $no_shift=1;
	    
	} elsif($token eq 'LINK_MIDDLE') {
	    # only treat this as special if we are parsing a link
	    if($context->name eq 'link') {
		$self->_parse_link_start($context, $tokens, 'key');

	    } else {
		# we don't have a link, so fall back to text
		$tokens->[0]=['',$txt];
	    }
	    $no_shift=1;

	} elsif($token eq 'LINK_DEF_START') {
	    $self->_parse_link_start($context, $tokens, 'url');
	    $no_shift=1;

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

	return '';
    }

    # this node should look like a block quote
    if($context->name ne 'blockquote') {
	warn 'Potentially bad state near ' . $context->text;
    }

    # replace the a blockquote node with the list we are currently parsing  
    $context->name=$list_type;
    $context->indent+=2;

    return 1;
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

	return '';
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
    return 1;
}

=head2 _parse_link_start

Handles the begining of a link block by converting it into a sequence of 
escape blocks

=cut

sub _parse_link_start {
    my ($self, $context, $tokens, $marker)=@_;
   
    # Links take the form of [text|key] or [text] or [text] <target>
    shift @$tokens;
    unshift @$tokens, ['TAG_BLOCK_START','{'];
    unshift @$tokens, ['', $marker];
    unshift @$tokens, ['ESCAPE',''];

    # # start a link 
    # $context->append_text(
    # 	$self->_parse_internal(
    # 	  Markup::Tree->new(
    # 	      name => 'link',
    # 	      indent => $context->indent,
    # 	      inline => 1),
    # 	    $tokens));


    # # Handle a [test|key] form link
    # if($tokens->[2]->[0] eq 'LINK_MIDDLE'
    #    and $tokens->[4]->[0] eq 'LINK_BLOCK_END') {

    # 	# retrieve the text part of our lookup
    # 	my ($link, $key)=map {$_->[1] } @{$tokens}[1,3];
	
    # 	# append the link and key nodes then return
    # 	my $key_node=Markup::Tree->new(
    # 	    name => 'key',
    # 	    inline => 1);
	
    # 	#TODO:append_text and append_node need to be rewritten
    # 	$key_node->append_text($key);
    # 	$key_node->append_node();
	
    # 	my $link_node=Markup::Tree->new(
    # 	    name => 'link',
    # 	    inline => 1);

    # 	$link_node->append_text($link);
    # 	$link_node->append_node();

    # 	$link_node->append_node($key_node);
	
    # 	$context->append_text($link_node);

    # 	splice @$tokens, 0,5;
	
    # } elsif ($tokens->[2]->[0] eq 'LINK_BLOCK_END'
    # 	     and $tokens->[3]->[0] eq 'LINK_DEF_START'
    # 	     and $tokens->[5]->[0] eq 'LINK_DEF_END') { # Handle a link def [link]<target>

    # 	# get the link value and target
    # 	my ($link, $url)=map { $_->[1]} @{$tokens}[1,4];

	
    # 	# build and append the various nodes
    # 	my $link_def_node=Markup::Tree->new(
    # 	    name => 'link_def');
	
    # 	$link_def_node->append_text($link);
    # 	$link_def_node->node='link';
    # 	$link_def_node->append_node();

    # 	$link_def_node->append_text($url);
    # 	$link_def_node->node='url';
    # 	$link_def_node->append_node();

    # 	$context->append_node($link_def_node);

    # 	splice @$tokens, 0,6;

    # } elsif($tokens->[2]->[0] eq 'LINK_BLOCK_END') { # handle links of the form [text]

    # 	my $link=$tokens->[1]->[1];

    # 	my $link_node=Markup::Tree->new(
    # 	    name => 'link',
    # 	    inline => 1);

    # 	$link_node->append_text($link);
    # 	$link_node->append_node();
	
    # 	$context->append_text($link_node);
	
    # 	splice @$tokens, 0,3;

    # } else { # this is not a link
    # 	$tokens->[0]->[0]='';
    # }
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
