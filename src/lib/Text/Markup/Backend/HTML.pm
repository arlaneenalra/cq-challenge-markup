package Text::Markup::Backend::HTML;

use strict;
use warnings;

use base 'Text::Markup::Base';

use Carp;

use fields qw/encoding lang resources links stack/;

# list of tags we should call start_<tag> on
my %html_tag = map { $_ => 1 } qw/ol ul li blockquote p h1 h2 h3 h4 h5 h6 pre i b body/;

# list of tags that require special processing
my %special_tag=(
                 'link' => \&process_link,
                 'key' => \&process_key,
                 'link_def' => \&process_link_def,
                );


=head1 NAME

Text::Markup::Backend::HTML - Produces simple HTML outputXS

=head1 SYNOPSIS

=cut

=head1 METHODS

=head2 extension

Return the default extension for files generated by this backend

=cut

sub extension {
  my ($self)=@_;

  return 'html';
}

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
    if (ref $token eq 'CODE') {
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
  if ($special_tag{$name}) {
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
or text and call backs.  Accepts a tree node and optionally
a flag indicating if formatting tags should be stripped.

=cut

sub process_tags {
  my ($self, $tree, $strip)=@_;

  my @tags;

  # walk all of the nodes in this nodes body
  foreach (@{$tree->body}) {

    if (ref $_) {               # a complex tag

      # if strip is set to true, only process the tags
      # contents
      if ($strip) {
        push @tags, $self->process_tags($_, 1);
      } else {
        push @tags, $self->string_internal($_);
      }

    } else {                    # we have a tag with inline content
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
  if ($html_tag{$name}) {
    push @tags, $self->render_html_tag($start_end, $name);

  } else {

    # treat inline tags as span and others as div
    push @tags, $self->render_html_tag(
                                       $start_end,
                                       $tree->inline() ? 'span':'div',
                                       {
                                        'class' => $name});
  }

  # if we are processing the body tag, we need to deal with
  # document level stuff
  if ($name eq 'body') {

    # postion wrapping tags correctly for
    # start or end
    if ($start_end) {
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

  if (!$start_end) {
    return "</$name>";
  }


  my $attributes='';

  # check for and process attributes
  if ($attributes_ref) {
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

=head2 process_link_def

Process link_def nodes to provide link node callbacks with values.

=cut

sub process_link_def {
  my ($self, $tree)=@_;

  # link_def elements should always have a link and url node
  # and only a link and url node.  Nothing else makes sense
  my ($key_ref, $url_ref)=@{$tree->body};

  # assumed to always have a pure text body
  my $key=$self->make_link_key($key_ref);
  my $url=join '', $self->process_tags($url_ref,1);

  # put this link definition into the link lookup hash
  $self->links->{$key}=$url;

  # link_def nodes never render content
  return ();
}

=head2 process_key

Process a key token by placing the contents of a key node into the links
hash for latter retrieval by a link callback

=cut

sub process_key {
  my ($self, $tree)=@_;

  # key nodes are assumed to have a pure text body.
  my $key=$self->make_link_key($tree);

  # add the key node to our link hash,
  # a link_def will latter look it up and attach a value to it.
  $self->links->{$key}='';

  # replace the last LINK tag that is supposed to
  # be on the stack with the key value we just found
  $self->stack->[-1]=['KEY', $key];

  # key's will neve have any contents to return
  return ();
}

=head2 process_link

Process links elements by adding a callback to the output token stream.  This
allows for links to be processed after the token stream is assembled.

=cut

sub process_link {
  my ($self, $tree)=@_;

  my $name=$tree->name;

  # push a link node onto the processing stack
  push @{$self->stack}, ['LINK', ''];

  # process the body of the node into tags
  my @tags=$self->process_tags($tree);

  # get rid of our flagging token
  my $ref = pop @{$self->stack};
  my $key;

  # Did we find a key tag somewhere in there?
  if ($ref->[0] eq 'KEY') {

    # key is in the second element of our tupple
    $key=$ref->[1];
  } else {

    # treat all of the tags we found as the key.
    # this is crude but should work for most cases.
    $key=$self->make_link_key($tree);
  }

  # create the link starting point callback
  my $link_start=sub {

    # lookup our target url
    my $target=$self->links->{$key};

    if (!$target) {
      carp "Link with key value '$key' is missing a target!";
    }

    return $self->render_html_tag(1, 'a', {'href' => $target});
  };

  # add the link start callback and ending tag
  @tags= (
          $link_start,
          @tags,
          $self->render_html_tag(0, 'a')
         );

  return @tags;
}

=head2 make_link_key

Converts an array of string values into a scalar key value for looking up
links in a case insensitive manner.

=cut

sub make_link_key {
  my ($self, $tree)=@_;

  # build a pure text version of this nodes body
  my $key=join '', $self->process_tags($tree, 1);

  $key=~tr/A-Z/a-z/;

  return $key;
}

=head2 _encode_entities

Used by Text::Markup::Backend::HTML to encode content that contains special
characters.

=cut

sub encode_entities {
  my ($self, $content)=@_;

  # avoid undef warning when content is undef
  $content=defined($content)?$content:'';

  $content=~s/&/&amp;/g;        # has to be done first
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
