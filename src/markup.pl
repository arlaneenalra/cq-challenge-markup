#!/usr/bin/env perl

# Mask any libraries in the current directory
no lib '.';
use lib 'lib';

# Petup a sane execution execution environment
use strict;
use warnings;
use diagnostics;

use Markup::Parser;
use Markup::Tokenizer;
use Markup::Backend::XML;
use Markup::Util qw/slurp/;


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

my $tokenizer=Markup::Tokenizer->new();
my $parser=Markup::Parser->new(tokenizer => $tokenizer);
my $backend=Markup::Backend::XML->new();

# Do we have a file on the command line or should we be 
# looking for a stream?
my $source=@ARGV ? &slurp($ARGV[0]) : &slurp(\*STDIN);

# parse the source
my $tree=$parser->parse($source);

use Data::Dumper;
print &Dumper($tree);

print $backend->string($tree);

=head1 INTERNALS

=cut

