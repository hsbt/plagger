package Plagger::Plugin::Publish::Email;
use strict;
use base qw( Plagger::Plugin );

use DateTime;
use DateTime::Format::Mail;
use Encode qw/ from_to encode/;
use Encode::MIME::Header;
use HTML::Entities;
use MIME::Lite;
use Digest::MD5 qw/ md5_hex /;

sub rule_hook { 'publish.entry' }

sub _clean_folder_part {
    my ($str)=@_;

    $str =~ s{\W+}{-}g;

    return $str;
}

sub folder_name {
    my ($self, $context, $args) = @_;
    my $cfg = $self->conf;
    my $feed       = $args->{feed};

    my $folder;
    if ($cfg->{use_feed_tags_as_folder}) {
        my @tags = @{ $feed->tags };
        $folder = join '.', map { _clean_folder_part($_) } @tags;
    }
    if ($cfg->{use_feed_title_as_folder}) {
        $folder .= '.' if $folder;
        $folder .= _clean_folder_part($feed->title->plaintext);
    }
    return $folder || $cfg->{folder};
}

sub prepare_entry {
    my($self, $context, $args) = @_;
    my $cfg = $self->conf;
    my $msg;
    my $entry      = $args->{entry};
    my $subject = eval { $entry->title->plaintext } || '(no-title)';

    my @enclosure_cb;

    if ($self->conf->{attach_enclosures}) {
        push @enclosure_cb, $self->prepare_enclosures($entry);
    }

    my $body = $self->templatize('mail.tt', $args);
    $body = encode("utf-8", $body);
    my $from = $cfg->{mailfrom} || 'plagger@localhost';
    my $id   = md5_hex($entry->id_safe);
    my $date = $entry->date || Plagger::Date->now(timezone => $context->conf->{timezone});
    my $from_name;
    if ($cfg->{use_entry_author_as_from} && $entry->author) {
    	$from_name=$entry->author->plaintext;
    }
    $from_name ||= $args->{feed}->title->plaintext;
    $from_name =~ tr/,//d;

    $msg = MIME::Lite->new(
        Date    => $date->format('Mail'),
        From    => encode('MIME-Header', qq("$from_name" <$from>)),
        To      => $cfg->{mailto},
        Subject => encode('MIME-Header', $subject),
        Type    => 'multipart/related',
    );
    $msg->attach(
        Type     => 'text/html; charset=utf-8',
        Data     => $body,
        Encoding => 'quoted-printable',
    );
    for my $cb (@enclosure_cb) {
        $cb->($msg);
    }
    $msg->add('Message-Id', "<$id.plagger\@localhost>");
    $msg->add('X-Tags', encode('MIME-Header', join(' ', @{ $entry->tags })));
    my $xmailer = "Plagger/$Plagger::VERSION";
    $msg->replace('X-Mailer', $xmailer);

    return $msg;
}

sub prepare_enclosures {
    my($self, $entry) = @_;

    if (grep $_->is_inline, $entry->enclosures) {

        # replace inline enclosures to cid: entities
        my %url2enclosure = map { $_->url => $_ } $entry->enclosures;

        my $output;
        my $p = HTML::Parser->new(api_version => 3);
        $p->handler(default => sub { $output .= $_[0] }, "text");
        $p->handler(
            start => sub {
                my($tag, $attr, $attrseq, $text) = @_;

                # TODO: use HTML::Tagset?
                if (my $url = $attr->{src}) {
                    if (my $enclosure = $url2enclosure{$url}) {
                        $attr->{src} = "cid:" . $self->enclosure_id($enclosure);
                    }
                    $output .= $self->generate_tag($tag, $attr, $attrseq);
                }
                else {
                    $output .= $text;
                }
            },
            "tag, attr, attrseq, text"
        );
        $p->parse($entry->body);
        $p->eof;

        $entry->body($output);
    }

    return sub {
        my $msg = shift;

        for my $enclosure (grep $_->local_path, $entry->enclosures) {
            if (!-e $enclosure->local_path) {
                Plagger->context->log(warning => $enclosure->local_path .  " doesn't exist.  Skip");
                next;
            }

            my %param = (
                Type     => $enclosure->type,
                Path     => $enclosure->local_path,
                Filename => $enclosure->filename,
            );

            if ($enclosure->is_inline) {
                $param{Id} = '<' . $self->enclosure_id($enclosure) . '>';
                $param{Disposition} = 'inline';
            }
            else {
                $param{Disposition} = 'attachment';
            }

            $msg->attach(%param);
        }
      }
}

sub generate_tag {
    my($self, $tag, $attr, $attrseq) = @_;

    return "<$tag " . join(
        ' ',
        map {
            $_ eq '/' ? '/' : sprintf qq(%s="%s"), $_,
              encode_entities($attr->{$_}, q(<>"'))
          } @$attrseq
      )
      . '>';
}

sub enclosure_id {
    my($self, $enclosure) = @_;
    return Digest::MD5::md5_hex($enclosure->url->as_string) . '@Plagger';
}

1;
