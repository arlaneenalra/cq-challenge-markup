#!/usr/bin/env perl

# Mask any libraries in the current directory
use FindBin;
use lib "$FindBin::Bin/lib";
no lib '.';

# Petup a sane execution execution environment
use strict;
use warnings;
use diagnostics;

use Carp;

use Text::Markup::Parser;
use Text::Markup::Tokenizer;
use Text::Markup::Util qw/slurp parse_args/;


# Make sure that we are actually dealing with uft8
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';

=head1 NAME

markup.pl - Tool to convert text written using Text::Markup into a simple 
xml document.

=head1 USAGE

markup.pl [--no-links] [filename] [-o outputfile] [-f formatter]

If no filename is provided, markup.pl will expect to receive input via stdin 
and send output to stdout.

=over

% cat test.txt | markup.pl

=back


=head2 --no-links 
    
Turns of link processing for the given document.

=head2 filename

Input filename, if left blank the processor looks to stdin.

=head2 -o outputfile

The output file to write to.  If no file is provided, the script 
outputs to stdout.

=head2 -f formatter

Output formatting module to be used.  This defaults to Text::Markup::Backend::XML 
and should be provided as a fully qualified pacakge name.  The module in question
must provide a method named string which accepts a Markup::Tree as its single 
argument and returns a scalar containing rendered output.

=cut

# setup default values for arguments
my ($no_links, $output, $formatter)=(0,'', 'Text::Markup::Backend::XML');

# parse arguments into reasonable values
my ($filename)=&parse_args(\@ARGV,{
    '--no-links' => {
        'accepts' => 0,
        'var' => \$no_links},

    '-o' => {
        'accepts' => 1,
        'var' => \$output},

    '-f' => {
        'accepts' => 1,
        'var' => \$formatter}});

print "$no_links:$output:$formatter:$filename:$/";

my $tokenizer=Text::Markup::Tokenizer->new(links => !$no_links);

my $parser=Text::Markup::Parser->new(tokenizer => $tokenizer);


## no critic (ProhibitStringyEval)

# create an instance of the backend
eval "require $formatter;"
    or croak "Unable to load $formatter due to $@";

## use critic

my $backend=$formatter->new();


# Do we have a file on the command line or should we be 
# looking for a stream?
my $source=$filename ? &slurp($filename) : &slurp(\*STDIN);

# parse the source
my $tree=$parser->parse($source);

# render output using the selected backend
my $string=$backend->string($tree);

# write to a given file or STDOUT
if($output) {
    open my $fh_output, '>', $output
        or croak "Unable to open output file $@";
    
    binmode $fh_output, ':encoding(utf8)';
    
    print $fh_output $string;

    close $fh_output;
    
} else {
    # use STDOUT
    print $string;
}


