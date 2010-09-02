#!/usr/bin/env perl

# Petup a sane execution execution environment
use strict;
use warnings;
use diagnostics;

# Provide a readable display of our parsed data structure
use Data::Dumper;

# Mask any libraries in the current directory
no lib '.';

# Definition of the various tokens 
my @token_patterns=(
    [qr(\*) => 'HEADER_TAG'], # Matches '*' which is used to indicate a header

    # TODO:  Add link processing

    [qr(\\) => 'TAG_START'], # Match the escape character
    [qr({) => 'TAG_BLOCK_START'], # Match the start of the a tag block
    [qr(}) => 'TAG_BLOCK_END'], # Match the end of a tag block

    # [qr(\[) => 'LINK_BLOCK_START'], # Match the start of a link block
    # [qr(\|) => 'LINK_MIDDLE'], # Match middle of a link block
    # [qr(\]) => 'LINK_BLOCK_END'], # Match the end of a link block

    
    [qr(  -) => 'UNORDER_LIST'], # Matches an unordered list
    [qr(  #) => 'ORDER_LIST'], # Matches an ordered list
    
    [qr(   ) => '3SPACE'], # Matches leading whitespace
    [qr(  ) => '2SPACE'], # Matches leading whitespace
    
    [qr($/\s*$/) => 'END_OF_PARAGRAPH'], # Matches an end of paragraph marker
    [qr($/) => 'END_OF_LINE'], # Matches an end of line marker
    );

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
    my @tokens=&tokenize($content);
    
    return \@tokens;
}

=head2 tokenize($content)

Takes in a scalar representing content and returns a string of tokens 
which can then be used to provide structure to our content.

=cut

sub tokenize {
    my ($content)=@_;
    
    # Convert tabs into spaces
    $content=~s/\t/        /g;
    
    
    # Loop until there is not more content to match
    my @tokens;
    while($content) {
	
	# Retrieve a token and add it to our
	# list of tokens
	my ($token, $txt)=&next_token($content);
	
	# strip matched text from the front of our content
	$content=substr $content, length $txt;
	push @tokens, [$token, $txt];

	# DEBUG: remove latter
	#print "Token: $token => !$txt!$/";
    }
    
    return @tokens;
}

=head2 next_token($content)

Retrieve the first token matched in the passed in content

=cut

sub next_token {
    my ($content)=@_;
    
    # Walk each pattern until we find one that matches
    foreach (@token_patterns) {
	my ($regex,$token)=@$_;

	# return the token and matched text
	if ($content=~/^$regex/) {
	    return ($token, $&);
	}
    }

    # We didn't match any tokens at the start of the line, let's see
    # if there are any further along
    my $matched;
    foreach (@token_patterns) {
	my ($regex,$token)=@$_;

	# does this regex match anywhere in the data?
	if($content=~m/$regex/) {
	    my $loc=index $content, $&;

	    # DEBUG: Remove latter
	    #print "MATCHED:$token => $loc$/";

	    # save off the earliest match we have
	    if(!$matched) {
		$matched=$loc;
	    } else {
		# is this match earlier than the last one . . .
		$matched=$loc < $matched ? $loc : $matched;
	    }
	}
    }

    # if any match succeded, then return a substring to that offset
    if(defined($matched)) {
	return ("", substr $content,0,$matched);
    }

    # nothing left but text
    return ("", $content);

    #die "Unable to match remaining content near : " . substr($content,0,20) . "...$/";
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





