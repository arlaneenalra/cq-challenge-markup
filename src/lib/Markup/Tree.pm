package Markup::Tree;

use strict;

use fields qw/indent text name body node escape verbatim/;

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
    };
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

=cut

1;
