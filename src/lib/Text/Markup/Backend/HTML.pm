package Text::Markup::Backend::HTML;

use strict;
use warnings;

use base 'Text::Markup::Base';

use Carp;

use fields qw/encoding lang resources links stack/;

# # list of tags that are considered containers and need to have
# # a $/ after the opening tag
# my %container = map { $_ => 1 } qw/blockquote ol ul li note p/;

# list of tags we should call start_<tag> on 
my %html_tag = map { $_ => 1 } qw/ol ul li blockquote p h1 h2 h3 h4 h5 h6 pre i b body/;

# list of tags that require special processing
my %special_tag=(
    'link' => \&process_link,
#    'key' => \&process_key,
#    'link_def' => &process_link_def,
    );


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

    my $string='';
    
    # convert the array of strings returned by string_internal into 
    # a single string
    foreach my $token ($self->string_internal($tree)) {

        # if we have a code ref, execute it
        if(ref $token eq 'CODE') {
            $string.=$token->();
        } else {
            $string.=$token;
        }
    }
    
    return $string;
}


=head2 string_internal

Does a first pass over the Text::Markup::Tree structure and setups up back references
for certain kinds of nodes that will be futher processed latter.

=cut

sub string_internal {
    my ($self, $tree)=@_;
    
    my $name=$tree->name;

    my @tags;

    # do we have a special case tag?
    if($special_tag{$name}) {
        return $special_tag{$name}->($self, $tree);
    }

    # render opening for current node
    push @tags, $self->render_tag(1, $tree);

    # process the body of this node
    push @tags, $self->process_tags($tree);

    # render closing for current node
    push @tags, $self->render_tag(0, $tree);

    return @tags;
}

=head2 process_tags

Takes the body of a node and converts it into an array
or text and call backs.

=cut

sub process_tags {
    my ($self, $tree)=@_;
    
    my @tags;

    # walk all of the nodes in this nodes body
    foreach (@{$tree->body}) {

        if(ref $_) { # a complex tag
            push @tags, $self->string($_);

        } else { # we have a tag with inline content
            push @tags, $self->encode_entities($_);
        }
    }
    
    return @tags;
}

=head2 start_document

Outputs the starting tags for an html document

=cut

sub start_document {
    my ($self)=@_;
    
    my @tags=(
        '<!DOCTYPE html>',
        '<head>',
        '<meta charset="' . $self->encoding() . '" />',
        '</head>',
        '<html lang="' . $self->lang() . '">',
        );
        
    return @tags;
}


=head2 end_document

Output ending tag and footers for html tags

=cut

sub end_document {
    my ($self)=@_;
    
    return ('</html>');
}


=head2 render_tag

Either renders the named html tag or renders a div/span using given node's
name as a class.

=cut

sub render_tag {
    my ($self, $start_end, $tree)=@_;

    my $name=$tree->name();
    my @tags;
    my $call='';

    # do we have an html tag or do we have 
    # something else?
    if($html_tag{$name}) {
        push @tags, $self->render_html_tag($start_end, $name);

    } else {

        # treat inline tags as span and others as div
        push @tags, $self->render_html_tag(
            $start_end, 
            $tree->inline() ? 'span':'div', 
            {'class' => $name});
    }

    # if we are processing the body tag, we need to deal with
    # document level stuff
    if($name eq 'body') {
        
        # postion wrapping tags correctly for 
        # start or end
        if($start_end) {
            @tags=($self->start_document(), @tags);
        } else {
            push @tags, $self->end_document();
        }
    }

    return @tags;
}

=head2 render_html_tag 

Generate an html start or end tag with the given class.

=cut

sub render_html_tag {
    my ($self, $start_end, $name, $attributes_ref)=@_;

    if(!$start_end) {
        return "</$name>";
    }

    
    my $attributes='';

    # check for and process attributes
    if($attributes_ref) {
        # convert attibute hash into 
        # a string of attributes
        $attributes=' ' . join ' ', map {
            $_ . '="' 
                . $self->encode_entities($attributes_ref->{$_})
                . '"';
        } keys %{$attributes_ref};
    }

    return '<' . $name . $attributes . '>';
}

=head2 process_link

Process links elements

=cut

sub process_link {
    my ($self, $tree)=@_;

    my $name=$tree->name;
    
    # push a link node onto the processing stack
    push @{$self->stack}, 'LINK';

    # process the body of the node into tags
    my @tags=$self->process_tags($tree);
    
    # get rid of our flagging token
    pop @{$self->stack};

    my $key='key';
    
    my $link_start=sub {
        return $self->render_html_tag(1, 'a', {'href' => $key});
    };
    
    # build the link start call
    my $link_end=sub {
        return $self->render_html_tag(0, 'a');
    };

    # return with link start and end references added in
    return ($link_start, @tags, $link_end);
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
        encoding => 'utf-8',
        lang => 'en',
        stack => [],
    };
}

=head1 FIELDS

=head2 links

Used internally by the formatter to keep track links in the document

=head2 stack

Used internally by the formatter to return data from nested nodes

=head2 encoding

Defines the character encoding for the current document.  Defaults to utf-8

=head2 lang

Define the language for the output file, defaults to en

=cut

1;
