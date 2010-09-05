package Markup::Backend::XML;

use strict;

use base 'Markup::Base';

# list of tags that are considered containers and need to have
# a $/ after the opening tag
my %container = map { $_ => 1 } qw/body blockquote ol ul/;

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
    my $text=$tree->text;
    my $string.='';

    # make sure that $extra_indent is a number
    $extra_indent=defined($extra_indent)?$extra_indent:0;
    
    # if we do not have a container tag, indent
    unless($container{$name}) {
	$extra_indent+=1;
    }

    # construct an indent block 
    my $indent= ' ' x (4 * (int($tree->indent /2) + $extra_indent));

    if($tree->verbatim) {
	$string=$indent . ($text?"<$name>":"<$name/>");
	$string.=$self->_encode_entities($text);
	$string.=$text?"</$name>":'';

    } else {
	# if we have no internals, start with an empty body
	$string=$indent . ((@{$tree->body})?"<$name>":"<$name/>");
	
	# put a $/ after opening container tags
	if($container{$name}) {
	    $string.=$/;
	}

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
		$string.=$self->string($_, $extra_indent);

	    } else { # we have a tag with inline content
		$string.=$_;
		
	    }
	    
	}
	
	unless($extra_indent) {
	    $string.=$indent;
	}
	# did we have an empty body tag?
	$string.=(@{$tree->body})?"</$name>":'';
    }

    # # convert indentations to 4 spaces
    # $string=~s/\t/    /g;
    unless($tree->inline) {
	$string.=$/;
    }

    return $string;
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
