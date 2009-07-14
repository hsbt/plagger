package Plagger::Subscription;
use strict;
use base qw( Plagger::Update );

sub new {
    my $class = shift;
    bless { feeds => [], feed_urls => {}, by_tags => {}, by_types => {} }, $class;
}

sub add {
    my($self, $feed) = @_;

    return if exists $self->{feed_urls}->{$feed->url};
    $self->{feed_urls}->{$feed->url}=undef;

    push @{ $self->{feeds} }, $feed;
    for my $tag ( @{$feed->tags} ) {
        push @{ $self->{by_tags}->{$tag} }, $feed;
    }
    push @{ $self->{by_types}->{$feed->type} }, $feed;
}

sub delete_feed {
    my($self, $feed) = @_;

    delete $self->{feed_urls}->{$feed->url};

    my @feeds = grep { $_ ne $feed } $self->feeds;
    $self->{feeds} = \@feeds;
}

sub types {
    my $self = shift;
    keys %{ $self->{by_types} };
}

sub feeds_by_type {
    my($self, $type) = @_;
    @{ $self->{by_types}->{$type} || [] };
}

1;
