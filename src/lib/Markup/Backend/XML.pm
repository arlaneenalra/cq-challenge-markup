package Markup::Backend::XML;

use strict;

use base 'Markup::Base';


=head1 NAME

Markup::Backend::XML - Produces simple XML output from a Markup::Tree instance

=head1 SYNOPSIS


=cut


=head1 METHODS

=head2 string

Convert the passed in Markup::Tree structure into a xml string.

=cut

sub string {
    my ($self, $tree, $extra_indent)=@_;
    
    my $name=$tree->name;
    my $string.='';

    # make sure that extra indent is a number
    $extra_indent=defined($extra_indent)?$extra_indent:0;

    # handle list items needing extra indentation
    if($name eq 'ol'
	or $name eq 'ul') {
	$extra_indent+=1;
    }
    
    # construct an indent block 
    my $indent= ' ' x (4 * (int($tree->indent /2) + $extra_indent));

    if($tree->verbatim) {
	$string=$indent . ($tree->text?"<$name>":"<$name/>");
	$string.=$self->_encode_entities($tree->text);
	$string.=$tree->text?"</$name>":'';

    } else {
	# if we have no internals, start with an empty body
	$string=$indent . ((@{$tree->body})?"<$name>$/":"<$name/>");

	#TODO: Actually do something with the backend

	foreach (@{$tree->body}) {
	    
	    if(ref $_ eq 'ARRAY') { # simple tag
		# handle a simple tag
		my ($tag, $content)=@{$_};

		# is there anything in this tag?
		if($content) {
		    $content=$self->_encode_entities($content);
		    $string.="$indent    <$tag>$content</$tag>$/";
		} else {
		    $string.="$indent    <$tag/>$/";
		}

	    } elsif(ref $_) { # a complex tag
		$string.=$self->string($_);
	    }
	    
	}


	# did we have an empty body tag?
	$string.=$indent . ((@{$tree->body})?"</$name>":'');
    }

    # # convert indentations to 4 spaces
    # $string=~s/\t/    /g;

    return $string . $/;
}


=head2 _encode_entities

Used by Markup::Backend::XML to encode content that contains special
characters

=cut

sub _encode_entities {
    my ($self, $content)=@_;

    $content=~s/&/&amp;/g; # has to be done first
    $content=~s/</&lt;/g;
    $content=~s/>/&gt;/g;
    
    return $content;
}

1;
