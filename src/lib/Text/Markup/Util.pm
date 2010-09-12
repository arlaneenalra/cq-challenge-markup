package Text::Markup::Util;

use strict;
use warnings;

use base 'Exporter';

use Carp;

=head1 NAME

Text::Markup::Util - A collection of utility methods used throughout the Text::Markup system

=head1 SYNOPSIS

This is a catch all module for functions that are used in several locations.

=cut

# setup a list of functions that may be exported into using modules
our @EXPORT_OK= qw/slurp parse_args/;


=head1 FUNCTIONS 

=head2 slurp

Takes in a file handle and slurps its entire contents into a scalar.

=cut

sub slurp {
    my ($file)=@_;

    local $/=undef; # set the end of line marker to undef 

    # If we were passed a file handle, slurp it and return
    # otherwise, we treat our argument as a filename.
    if(ref $file eq 'GLOB') {
        return <$file>;
    }

    open my $fh, '<', $file
        or croak "Unable to open file $file due to: $!";
    
    binmode $fh, ":encoding(utf8)"; # set utf8 encoding
    
    # load the entire file into memory
    my $content=<$fh>;

    close $fh; # clean up properly

    return $content;
}

=head2 parse_args

Convert the arguments array into a set of scalars we can use for 
configuration choices.  Unmatched, defined arguments are returned.
Parameters may be defined to accept one or no arguments.  If a given
parameter accepts one argument, its value is treated as true or false.
If a given parameter is defined as accepting one argument, the value 
immediately following that parameter in the argument array is assumed 
to be the argument.  Matched parameters have no defined order.

Example:

=over


=back

=cut
sub parse_args {
    my ($args_ref, $param_ref)=@_;

    if(!@{$args_ref}) {
        return;
    }

    # walk the list of possible parameters and see
    # if any of them match
    foreach my $param ( keys %{$param_ref}) {
        my ($accepts, $var_ref)=@{$param_ref->{$param}}{'accepts', 'var'};

        my $value=&parse_param($param, $accepts, $args_ref);

        # only assign to our variable reference if
        # we actually found something.
        if(defined($value)) {
            ${$var_ref}=$value;
        }

    }
    
    # prune all undefined values from the argument list
    my @unmatched=grep { defined($_) } @{$args_ref};
    
    return @unmatched;
}

=head2 parse_param

Look for an argument that accepts a single parameter, return that 
parameter and remove the parameter, flag from the argument array

=cut

sub parse_param {
    my ($param, $accepts, $args_ref)=@_;

    # look for the argument
    my ( $index )=grep {
        $args_ref->[$_] and
            $args_ref->[$_] eq $param 
    } 0..$#{$args_ref};

    # if this parameter does not accept an argument, we 
    # just need to know if it was in the list
    if(!$accepts) {

        # remove the parameter from our param list
        if(defined($index)) {
            $args_ref->[$index]=undef;

            return 1;
        }
        
    } elsif(defined($index)) {
        my $value=$args_ref->[$index+1];
        
        # clear -o filename from the array
        $args_ref->[$index]=undef;
        $args_ref->[$index+1]=undef;

        return $value;
    }
    
    # no match found
    return;
}

1;
