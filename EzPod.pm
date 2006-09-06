=head1 NAME

XML::Filter::EzPod - A SAX filter (for Pod::SAX) that makes writing Pod easier.

=head1 SYNOPSIS

  my $p = Pod::SAX->new(
            Handler => XML::Filter::EzPod->new(
                Handler => XML::SAX::Writer->new(
                    Output => \$output
                )
            )
        );

=head1 DESCRIPTION

Don't you just get sick of writing lists in pod? So much annoying vertical
whitespace! I got sick of it too. So this filter turns something like:

    * A bullet
    * Point
    ** With extra levels
    ** Going
    *** Up
    ** and
    * Down
    ** And up again

Into the appropriate SAX events as though the source were a POD list.

=head1 SUPPORTED SYNTAX

=head2 Itemized Lists

Can be created with asterisks. These must be in the first column, and followed
by whitespace. Arbitrary asterisk levels are supported.

Example:

  * an itemized
  * list is created
  * as follows
  ** with possible further indents

=head2 Ordered Lists

Can be created with hashes (also known as the pound sign). These must be in the
first column and followed by whitespace. Arbitrary levels are supported.

Example:

  # An ordered
  # list is created
  # as follows
  ## with possible
  ## further indents

=head2 The C<indent_width> Value

It is possible to set the value normally given in POD's C<=over N> parameter
using the greater-than sign before your list:

  >6
  * A bulleted list
  * equivalent to =over 6

A single greater-than sign on its own will set the C<indent_width> to I<-1> which
is useful in conjunction with AxKit2's I<spod5> plugin, indicating the points
should appear incrementally.

A double greater-than sign will set the C<indent_width> to I<-2>. Again, for
spod5, indicating the points should appear incrementally with the first point
shown automatically.

=head1 LICENSE

This is free software. You may use it and redistribute it under the same terms
as perl itself.

=head1 AUTHOR

Matt Sergeant, <matt@sergeant.org>

=head1 BUGS

The test suite doesn't actually test anything - it's there for me as a visual
inspection to check everything's working.

=cut

package XML::Filter::EzPod;

use strict;

our $VERSION = '1.0';

use XML::SAX::Base;

use base qw(XML::SAX::Base);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{in_paragraph} = 0;
    return $self;
}

sub start_element {
    my ($self, $el) = @_;
    
    if ($el->{LocalName} eq 'para') {
        $self->{in_paragraph}++;
    }
    elsif ($self->{in_paragraph}) {
        $self->{in_paragraph}++;
    }
    
    $self->SUPER::start_element($el);
}

sub end_element {
    my ($self, $el) = @_;
    
    if ($self->{in_paragraph}) {
        $self->{in_paragraph}--;
    }
    
    $self->SUPER::end_element($el);
}

sub characters {
    my ($self, $data) = @_;
    
    if ($self->{in_paragraph}) {
        #print "Chars: $data->{Data}\n";
        if ($data->{Data} =~ /^[\*\#]/m) {
            # likely candidate for turning into bullet points
            my @lines = split(/\n/, $data->{Data});
            my $ol_level = 0;
            my $ul_level = 0;
            my $indent = 4;
            foreach my $line (@lines) {
                if ($line =~ /^>(>?)$/) {
                    if ($1) {
                        $indent = "-2";
                    }
                    else {
                        $indent = "-1";
                    }
                    next;
                }
                elsif ($line =~ /^>(\d+)$/) {
                    $indent = $1;
                    next;
                }
                if ($line =~ s/^(\*+)\s//) {
                    my $depth = length($1);
                    if ($ol_level) {
                        for (1 .. $ol_level) {
                            #print "</ol>\n";
                            $self->SUPER::end_element(_element('orderedlist'));
                        }
                        $ol_level = 0;
                    }
                    my $diff = $depth - $ul_level;
                    while ($diff) {
                        if ($diff > 0) {
                            #print "<ul>\n";
                            $self->SUPER::start_element(
                                _add_attrib(_element('itemizedlist'), indent_width => $indent)
                            );
                            $diff--;
                        }
                        else {
                            #print "</ul>\n";
                            $self->SUPER::end_element(_element('itemizedlist', 1));
                            $diff++;
                        }
                    }
                    $ul_level = $depth;
                    #print "$line\n";
                    $self->SUPER::start_element(_element('listitem'));
                    $self->SUPER::characters({ Data => $line });
                    $self->SUPER::end_element(_element('listitem', 1));
                }
                elsif ($line =~ s/^(\#+)\s//) {
                    my $depth = length($1);
                    if ($ul_level) {
                        for (1 .. $ul_level) {
                            $self->SUPER::end_element(_element('itemizedlist'));
                        }
                        $ul_level = 0;
                    }
                    my $diff = $depth - $ol_level;
                    while ($diff) {
                        if ($diff > 0) {
                            #print "<ol>\n";
                            $self->SUPER::start_element(
                                _add_attrib(_element('orderedlist'), indent_width => $indent)
                            );
                            $diff--;
                        }
                        else {
                            #print "</ol>\n";
                            $self->SUPER::end_element(_element('orderedlist', 1));
                            $diff++;
                        }
                    }
                    $ol_level = $depth;
                    #print "$line\n";
                    $self->SUPER::start_element(_element('listitem'));
                    $self->SUPER::characters({ Data => $line });
                    $self->SUPER::end_element(_element('listitem', 1));
                }
                else {
                    $self->SUPER::characters({ Data => $line });
                }
            }
            for (1 .. $ol_level) {
                #print "</ol>\n";
                $self->SUPER::end_element(_element('orderedlist'));
            }
            for (1 .. $ul_level) {
                #print "</ul>\n";
                $self->SUPER::end_element(_element('itemizedlist'));
            }
            return;
        }
    }
    
    $self->SUPER::characters($data);
}

sub _element {
    my ($name, $end) = @_;
    return { 
        Name => $name,
        LocalName => $name,
        $end ? () : (Attributes => {}),
        NamespaceURI => '',
        Prefix => '',
    };
}

sub _add_attrib {
    my ($el, $name, $value) = @_;
    
    $el->{Attributes}{"{}$name"} =
      {
	  Name => $name,
	    LocalName => $name,
	    Prefix => "",
	    NamespaceURI => "",
	    Value => $value,
      };
      
    return $el;
}

1;
