package Markup::Tree;

use strict;

use fields qw/indent text name body node escape verbatim backend/;

use base 'Markup::Base';

=head1 NAME

Markup::Tree - Stores the parse tree 

=head1 SYNOPSIS

This class is used by the parser to store context information
about various nodes as they are being parsed.  

=cut

=head1 METHODS

=head2 append_text

Append text to the end of the node we are currently working on.

=cut

sub append_text {
    my ($self, $text)=@_;
    
    $self->text = $self->text .  $text;
}

=head2 append_node

Append a new internal node to the body of whatever node we are currently working
on.  If no value is given, it assumes that text contains the value of the
node to be appended

=cut

sub append_node {
    my ($self, $node)=@_;

    # do we have a simple or complex node
    if($node) {
	# add a complex node
	push @{$self->body}, $node;

	# warn of possible syntax error
	if($self->text) {
	    warn 'Possible bad state while appending ' . 
		$node->name . ' near : ' . $self->text;
	}

    } else {
	# add a simple node
	push @{$self->body}, [
	    $self->node => $self->text
	];
    }
    

    # put us back into the default parsing state
    $self->reset(qw/node text/);
}

=head2 default_values

Setup sane defaults.

=cut

sub default_values {

    return {
	indent =>0,
	text => '',
	body => [],
	node => 'p',
	escape => '',
	name => 'body',
	verbatim => '',
	backend => 'Markup::Backend::XML',
    };
}

=head2 string

Process this tree using the given backend, it defaults to Markup::Backend::Xml

=cut

sub string {
    my ($self, $backend)=@_;
    
    my $name=$self->name;
    my $string.='';
    
    # construct an indent block 
    my $indent= ' ' x (4 * int($self->indent /2));

    if($self->verbatim) {
	$string=$indent . ($self->text?"<$name>":"<$name/>");
	$string.=$self->_encode_entities($self->text);
	$string.=$self->text?"</$name>":'';

    } else {
	# if we have no internals, start with an empty body
	$string=$indent . ((@{$self->body})?"<$name>$/":"<$name/>");

	#TODO: Actually do something with the backend

	foreach (@{$self->body}) {
	    
	    if(ref $_ eq 'ARRAY') { # simple tag
		# handle a simple tag
		my ($tag, $content)=@{$_};

		# is there anything in this tag?
		if($content) {
		    $content=$self->_encode_entities($content);
		    $string.="$indent    <$tag>$content</$tag>$/";
		} else {
		    $string.="$indent    <$tag/>$/";
		}

	    } elsif(ref $_) { # a complex tag
		$string.=$_->string($backend);
	    }
	    
	}


	# did we have an empty body tag?
	$string.=$indent . ((@{$self->body})?"</$name>":'');
    }

    # # convert indentations to 4 spaces
    # $string=~s/\t/    /g;

    return $string . $/;
}

=head2 _encode_entities

Used by Markup::Backend::XML to encode content that contains special
characters

=cut

sub _encode_entities {
    my ($self, $content)=@_;

    $content=~s/&/&amp;/g; # has to be done first
    $content=~s/</&lt;/g;
    $content=~s/>/&gt;/g;
    
    return $content;
}

=head1 FIELDS
    
Meanings and uses for some of the public accessible fields

=head2 name 

Name for the enclosing block defined by this tree node.

=head2 escape

If this is set to true, we have previously seen an escape token
and are waiting for the next token to process.

=head2 indent

Indicates the current level of indentation in.

=head2 verbatim

If this is set to true it indiciates that the content of this node 
should be treated as pure text only.  (There are no child nodes.)

=head2 backend

The default backend used when string is called

=cut

1;
