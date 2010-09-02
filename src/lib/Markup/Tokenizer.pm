package Markup::Tokenizer;

use strict;

use fields qw//;

use base 'Markup::Base';

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

=head1 NAME

Markup::Tokenizer - Takes a string and returns an array of tokens

=head1 SYNOPSIS


=head1 METHODS

=head2 tokenize($content)

Takes in a scalar representing content and returns a string of tokens 
which can then be used to provide structure to our content.

=cut

sub tokenize {
    my ($self, $content)=@_;
    
    # Convert tabs into spaces
    $content=~s/\t/        /g;
    
    
    # Loop until there is not more content to match
    my @tokens;
    while($content) {
	
	# Retrieve a token and add it to our
	# list of tokens
	my ($token, $txt)=$self->next_token($content);
	
	# strip matched text from the front of our content
	$content=substr $content, length $txt;
	push @tokens, [$token, $txt];

	# DEBUG: remove latter
	#print "Token: $token => !$txt!$/";
    }
    
    return @tokens;
}

=head2 next_token($content)

Retrieve the first token matched in the passed in content and return a pair containing
a token name and the matched text.

=cut

sub next_token {
    my ($self, $content)=@_;
    
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

1;
