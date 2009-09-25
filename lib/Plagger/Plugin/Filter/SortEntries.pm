package Plagger::Plugin::Filter::SortEntries;
use strict;
use warnings;
use base qw( Plagger::Plugin );
sub register {
    my ( $self, $c ) = @_;
    $c->register_hook(
        $self,
        'publish.feed'  => $self->can('entries'),
    );
}
sub entries {
    my ( $self, $c, $args ) = @_;
    my @entries = $args->{'feed'}->entries;
    @entries = sort { Plagger::Date->compare( $a->date, $b->date ) } @entries;
    @entries = reverse @entries if ( $self->conf->{'reverse'} );
    $args->{'feed'}->{'entries'} = \@entries;
    return 1;
}
1;
__END__
=head1 NAME
Plagger::Plugin::Filter::SortEntries - Sort entries of Feed.
=head1 SYNOPSIS
  - module: Filter::SortEntries
    config:
      property: date->format('Epoch')
      reverse: 1
=head1 DESCRIPTION
This plug-in sorts entry of Feed.
=head1 CONFIG
=head2 property
specification property for sorting.
=head2 reverse
reverse of sort result
=head1 AUTHOR
Naoki Okamura (Nyarla,) E<lt>thotep@nyarla.netE<gt>
=head1 LICENSE
This Plug-in is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
=head1 SEE ALSO
L<Plagger>
=cut

