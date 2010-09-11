package Text::Markup::Tester;

use strict;
use warnings;
use diagnostics;

use base 'Exporter';

our @EXPORT=qw/run_test/;

# Required for the test suite
use Text::Markup::Parser;
use Text::Markup::Tokenizer;
use Text::Markup::Backend::XML;
use Text::Markup::Util qw/slurp/;

use Test::Simple tests => 1;

=head1 NAME

Text::Markup::Tester - Used to run one of the test files as an individual test case

=head1 SYNOPSIS

If you create a .t file named after the test you wish to run containing the 
following or similar code, this module will do a string equality check between
the a source .txt file and the a result .xml file.

use Text::Markup::Tester;
run_test($path_to_data_files, $0);

=cut

=head1 METHODS

=head2 run_test

Takes a path to the test data files and a name for the test file.  

=cut

sub run_test {
    my ($path, $test)=@_;

    # strip off the .t
    $test=~s/\.t$//;
    $test=~s/.*\///;

    $path.="/$test";
    
    
    # construct a new instance of everything to make sure 
    # various portions of the tests do not interactive with 
    # each other in negative or positive manners
    my $tokenizer=Text::Markup::Tokenizer->new();
    my $parser=Text::Markup::Parser->new(tokenizer => $tokenizer);
    my $backend=Text::Markup::Backend::XML->new();
    
    my $xml=&slurp("$path.xml");
    my $source=&slurp("$path.txt");
    
    # parse the source tree
    my $tree=$parser->parse($source);
    
    # call our back end handler to convert 
    # to the simple xml format
    my $output=$backend->string($tree);
    
    # a naive approach to checking output
    ok($output eq $xml, "$test - Chcking Output");
}


1;
