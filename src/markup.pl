#!/usr/bin/env perl

# Petup a sane execution execution environment
use strict;
use warnings;
use diagnostics;

# Provide a readable display of our parsed data structure
use Data::Dumper;

# Mask any libraries in the current directory
no lib '.';

# Make sure that we are actually dealing with uft8
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';

=head1 NAME

markup.pl - Tool to convert text written using Markup into a simple 
xml document.

=head1 SYNOPSIS

markup.pl [filename]

If no filename is provided, markup.pl will expect to receive input via stdin 
and send output to stdout.

=over

cat test.txt | markup.pl

=back


=cut

# Do we have a file on the command line or should we be 
# looking for a stream?
my $source= @ARGV ? &slurp($ARGV[0]) : &slurp(\*STDIN);


=head1 UTILITY FUNCTIONS


=cut


=head2 slurp

Takes in a file handle and slurps its entire contents into a scalar.

=cut

sub slurp {
    my ($file)=@_;

    local $/; # set the end of line marker to undef 

    # If we were passed a file handle, slurp it and return
    # otherwise, we treat our argument as a filename.
    if(ref $file eq 'GLOB') {
	return <$file>;
    }


    open my $fh, '<', $file
	or die "Unable to open file $file due to: $!";
    
    binmode $fh, ":encoding(utf8)"; # set utf8 encoding
    
    my $content=<$fh>;

    close $fh; # clean up properly

    return $content;
}





