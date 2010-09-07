package Markup::Tokenizer;

use strict;

use fields qw//;

use base 'Markup::Base';

# Definition of the various tokens 
my @token_patterns=(
    [qr(-\*-.*-\*-) => 'EMACS_MODE'], # Match this so we can ignore it

    [qr(\*\** ) => 'HEADER_TAG'], # Matches '*' which is used to indicate a header

    # TODO:  Add link processing

    [qr(\\) => 'ESCAPE'], # Match the escape character
    [qr({) => 'TAG_BLOCK_START'], # Match the start of the a tag block
    [qr(}) => 'TAG_BLOCK_END'], # Match the end of a tag block

    # [qr(\[) => 'LINK_BLOCK_START'], # Match the start of a link block
    # [qr(\|) => 'LINK_MIDDLE'], # Match middle of a link block
    # [qr(\]) => 'LINK_BLOCK_END'], # Match the end of a link block

    
    [qr(- ) => 'UNORDERED_LIST'], # Matches an unordered list
    [qr(# ) => 'ORDERED_LIST'], # Matches an ordered list
    
    [qr/   */ => 'INDENT'], # Matches 2 or more leading spaces 
    
    [qr($/\s*($/)+) => 'END_OF_PARAGRAPH'], # Matches an end of paragraph marker
    [qr($/) => 'END_OF_LINE'], # Matches an end of line marker
    );

# list tokens that may only appear after certain other tokens
# +ANY+ means it must follow a token and +DELETE+ means, to 
# remove the token rather than converting it to a text token
my %token_rules=(
    'HEADER_TAG' => [qw/+UNDEF+ INDENT END_OF_LINE END_OF_PARAGRAPH/],
    'UNORDERED_LIST' => [qw/INDENT/],
    'ORDERED_LIST' => [qw/INDENT/],
    'INDENT' => [qw/+UNDEF+ END_OF_LINE END_OF_PARAGRAPH/],

    'END_OF_PARAGRAPH' => [qw/+ANY+ +DELETE+/],
    'END_OF_LINE' => [qw/+ANY+ +DELETE+/],
    'EMACS_MODE' => [qw/+DELETE+/],
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
    
    # Loop until there is not more content to match
    my @tokens;
    my $last_token=undef;
    while($content) {
	
	# Retrieve a token and add it to our
	# list of tokens
	my ($token, $txt)=$self->next_token($content);

	my $delete='';
	my $match=1;
	
	# strip matched text from the front of our content
	$content=substr $content, length $txt;

	# check for special case tokens
	if($token_rules{$token}) {
	    
	    # look for any matching rules
	    $match=grep { 

		(defined($last_token) and
		    ($last_token eq $_ or $_ eq '+ANY+'))

		    or (!defined($last_token) and
			$_ eq '+UNDEF+')

	    } @{$token_rules{$token}};

	    # should this token be deleted?
	    $delete=grep {
		$_ eq '+DELETE+'
	    } @{$token_rules{$token}};
	    
	    # we only do the delete if we didn't match
	    $delete=($delete and !$match);
	    
	    unless($match) {
		# convert special case tokens to plain text
		$token='';
	    }
	}

	print $/;

	# Should we completely ignore this token?
	unless($delete) {
	    $last_token=$token;
	    push @tokens, [$token, $txt];
	}

    }
    
    use Data::Dumper;
    print &Dumper(\@tokens);
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

}

1;
