package Markup::Backend::HTML;

use strict;
use warnings;

use base 'Markup::Base';

use CGI; # used for html generation

use fields qw/html links/;

# # list of tags that are considered containers and need to have
# # a $/ after the opening tag
# my %container = map { $_ => 1 } qw/blockquote ol ul li note p/;

# list of tags we should call start_<tag> on 
my %html_tag = map { $_ => 1 } qw/ol ul li blockquote p h1 h2 h3 h4 pre i b/;


=head1 NAME

Markup::Backend::HTML - Produces simple HTML output using CGI.pm as a generator

=head1 SYNOPSIS

=cut

=head1 METHODS

=head2 string

=cut

sub string {
    my ($self, $tree)=@_;
    
    my $html=$self->html;
    my $name=$tree->name;
    my $string='';

    # if we are the root node, do a start html
    if($name eq 'body') {
        $string .= $html->start_html();
    }

    # do we have an html tag or do we have 
    # something else?
    if($html_tag{$name}) {
        my $call="start_$name";
        $string.=$html->$call();
    } else {

        if($tree->inline) {
            $string.=$html->start_span({-class => $name});
        } else {
            $string.=$html->start_div({-class => $name});
        }
    }      

    # walk all of the nodes in this nodes body
    foreach (@{$tree->body}) {

        if(ref $_) { # a complex tag
            $string.=$self->string($_);

        } else { # we have a tag with inline content
            $string.=$html->escapeHTML($_);

        }

    }

    if($html_tag{$name}) {
        my $call="end_$name";
        $string.=$html->$call();
    } else {
        if($tree->inline) {
            $string.=$html->end_span();
        } else {
            $string.=$html->end_div();
        }
    }


    if($name eq 'body') {
        $string .= $html->end_html();
    }

    return $string;
}


=head2 default_values
    
Define some sane defaults as per Markup::Base

=cut

sub default_values {
    
    return {
        links => {},
        html => CGI->new(),
    };
}


1;
