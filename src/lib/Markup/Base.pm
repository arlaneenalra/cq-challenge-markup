package Markup::Base;

use strict;
use warnings;
use diagnostics;

use fields qw//;

=head1 NAME

Markup::Base - Base class for Markup components.

=head1 SYNOPSIS

This class provides a simple construct which checks/sets a known list of 
arguments.  A subclass may override B<required_args> to change the list of
valid arguments.

=cut

=head1 METHODS

=head2 new

Semi-Universal constructor

=cut

sub new {
    my ($self, @args)=@_;
    
    # Setup the fields hash
    $self=fields::new($self)
	unless ref $self;
    
    # Convert our arguments to a hash
    my %args=@args;

    # Map passed in arguments into their appropriate
    # locations
    foreach (keys %args) {
	$self->{$_}=$args{$_};
    }

    # Make sure that we've set all required arguments
    my @required_args=$self->required_args;
    my @not_set;
    foreach (@required_args) {
	push @not_set, $_
	    unless exists $args{$_};
    }

    if(@not_set) {
	die 'Required argument' . (@not_set>1? 's ' : ' ') . join(', ', @not_set) . ' have not been propperly set.';
    }
    
    return $self;
}


=head2 required_args

Default implementation of required_args which requires nothing.  Sub-Classes should 
implement their own version whih returns an array of argument names.

=cut

sub required_args {
    return ();
}

1;
