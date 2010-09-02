#!/usr/bin/env perl

# Mask any libraries in the current directory
no lib '.';
use lib 'lib';

# Petup a sane execution execution environment
use strict;
use warnings;
use diagnostics;

# Provide a readable display of our parsed data structure
use Data::Dumper;

#use Markup::Parser;
use Markup::Tokenizer;


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
my $source=@ARGV ? &slurp($ARGV[0]) : &slurp(\*STDIN);

print &Dumper(&parse($source));

=head1 INTERNALS

=head2 parse($content)

Accepts a scalar containing text and parses it into an internal parser tree.

TODO: Add a better description here

=cut

sub parse {
    my ($content)=@_;
   
    # Normalize on a standard eol
    $content=&normalize($content);

    # Convert the content into a stream of tokens
    my @tokens=&Markup::Tokenizer::tokenize($content);
    
    return \@tokens;
}

=head1 UTILITY FUNCTIONS 

Descriptions of some of the internals that have very little to do with 
overall usage.

=head2 normalize_eol

Converts end of line characters into the default for the platform markup.pl
is currently running on.

=cut

sub normalize {
    my ($content)=@_;
    
    # match all four of the common eol markers
    $content=~s/\n|\r\n|\n\r|\r/$\//g;
    
    return $content;
}

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





