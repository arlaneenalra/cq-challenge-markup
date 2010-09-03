package Markup::Tree;

use strict;

use fields qw/indent text body node/;

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
    push @{$self->body}, {
	$self->node => $self->text
    };
    

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
    };
}

# =head2 required_args
    
# Returns an array of required constructor arugments.

# =cut

# sub required_args {
#     return qw/name/;
# }


1;
