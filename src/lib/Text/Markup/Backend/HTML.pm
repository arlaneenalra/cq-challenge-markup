package Text::Markup::Backend::HTML;

use strict;
use warnings;

use base 'Text::Markup::Base';

use Carp;

use fields qw/html links/;

# # list of tags that are considered containers and need to have
# # a $/ after the opening tag
# my %container = map { $_ => 1 } qw/blockquote ol ul li note p/;

# list of tags we should call start_<tag> on 
my %html_tag = map { $_ => 1 } qw/ol ul li blockquote p h1 h2 h3 h4 h5 h6 pre i b body/;


=head1 NAME

Text::Markup::Backend::HTML - Produces simple HTML outputXS

=head1 SYNOPSIS

=cut

=head1 METHODS

=head2 string

Convert a given Text::Markup::Tree structure into html document defaults to HTML 5

=cut

sub string {
    my ($self, $tree)=@_;
    
    my $name=$tree->name;
    my $string='';


    # # do we have a link definition rather than a normal tag?
    # if($name eq 'link'
    #    or $name eq 'link_def') {
    #     return $self->process_link($tree);
    # }

    # render opening for current node
    $string.=$self->render_tag(1, $tree);

    # walk all of the nodes in this nodes body
    foreach (@{$tree->body}) {

        if(ref $_) { # a complex tag
            $string.=$self->string($_);

        } else { # we have a tag with inline content
            $string.=$self->encode_entities($_);
        }
    }

    # render closing for current node
    $string.=$self->render_tag(0, $tree);

    return $string;
}

=head2 start_document

Outputs the starting tags for an html document

=cut

sub start_document {
    my ($self)=@_;
    
    return '<!DOCTYPE HTML>
<html>
<head>
</head>
';

}


=head2 end_document

Output ending tag and footers for html tags

=cut

sub end_document {
    my ($self)=@_;
    
    return '</html>';

}


=head2 render_tag

Either renders the named html tag or renders a div/span using given node's
name as a class.

=cut

sub render_tag {
    my ($self, $start_end, $tree)=@_;

    my $name=$tree->name();
    my $tag='';
    my $call='';

    # do we have an html tag or do we have 
    # something else?
    if($html_tag{$name}) {
        $tag.=$self->render_html_tag($start_end, $name);

    } else {

        # treat inline tags as span and others as div
        $tag.=$self->render_html_tag(
            $start_end, 
            $tree->inline() ? 'span':'div', 
            $name);
    }

    # if we are processing the body tag, we need to deal with
    # document level stuff
    if($name eq 'body') {
        
        # postion wrapping tags correctly for 
        # start or end
        if($start_end) {
            $tag=$self->start_document() . $tag;
        } else {
            $tag.=$self->end_document();
        }
    }

    return $tag;
}

=head2 render_html_tag 

Generate an html start or end tag with the given class.

=cut

sub render_html_tag {
    my ($self, $start_end, $name, $class)=@_;

    $class=$class?" class=\"$class\"":'';

    if ($start_end) {
        return "<$name$class>";
    }

    return "</$name>";
}

=head2 process_link

Process links and link_def elements

=cut

sub process_link {
    my ($self, $tree)=@_;

    my $name=$tree->name;
    my $string='';
    
    # # handle a link
    # if($name eq 'link') {
    #     my $key='';
        
    #     # process each body node in
    #     foreach (@{$tree->body}) {
    #         # do we have a key tag inside this link's
    #         # body?
    #         if($_->name eq 'key') {
    #             $key=$self->string($_);
    #         }
    #     }
    # }

    
    #TODO : Add link processing code here.
    
    return '';
}

=head2 _encode_entities

Used by Text::Markup::Backend::HTML to encode content that contains special
characters.

=cut

sub encode_entities {
    my ($self, $content)=@_;

    $content=~s/&/&amp;/g; # has to be done first
    $content=~s/</&lt;/g;
    $content=~s/>/&gt;/g;
    
    return $content;
}

=head2 default_values
    
Define some sane defaults as per Text::Markup::Base

=cut

sub default_values {
    
    return {
        links => {},
    };
}


1;
