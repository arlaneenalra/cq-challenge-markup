package Markup::Tree;

use strict;

use fields qw/indent text body node escape/;

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
on.  It assumes that text contains the content of our current node

=cut

sub append_node {
    my ($self)=@_;

    # add the node
    push @{$self->body}, [
	$self->node => $self->text
    ];
    

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
    };
}

=head2 string

Process this tree using the given backend, it defaults to Markup::Backend::Xml

=cut

sub string {
    my ($self, $backend)=@_;

    # if we have no internals, start with an empty body
    my $string=(@{$self->body})?"<body>$/":'<body/>';

    #TODO: Actually do something with the backend
    
    foreach (@{$self->body}) {
	# handle a simple tag
	my ($tag, $content)=@{$_};
	
	# simple tag
	$string.="\t<$tag>$content</$tag>$/";
	
    }

    # did we have an empty body tag?
    $string.=(@{$self->body})?'</body>':'';

    # convert indentations to 4 spaces
    $string=~s/\t/    /g;

    return $string . $/;
}

=head1 FIELDS
    
Meanings and uses for some of the public accessible fields


=head2 escape

If this is set to true, we have previously seen an escape token
and are waiting for the next token to process.

=cut

1;
