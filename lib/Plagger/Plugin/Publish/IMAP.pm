package Plagger::Plugin::Publish::IMAP;
use strict;
use base qw( Plagger::Plugin::Publish::Email );

use Encode qw/ from_to encode/;
use IO::File;
use IO::Socket::SSL;
use Mail::IMAPClient;
use Digest::MD5 qw/ md5_hex /;

sub register {
    my($self, $context) = @_;
    $self->{version} = '0.1';
    $context->register_hook(
        $self,
        'plugin.init'      => \&initialize,
        'publish.entry'    => \&store_entry,
        'publish.finalize' => \&finalize,
    );
}

sub rule_hook { 'publish.entry' }

sub ensure_folder {
    my ($self,$context,$folder,$cfg)=@_;

    $folder=encode($cfg->{folder_encoding} || 'IMAP-UTF-7',$folder);

    if ($folder && !$self->{imap}->exists($folder)) {
        $self->{imap}->create($folder)
          or die $context->log(error => "Could not create $folder: $@");
        $context->log(info => "Create new folder ($folder)");
    }

    return;
}

sub initialize {
    my($self, $context, $args) = @_;
    my $cfg = $self->conf;

    my $socket = undef;
    if ($cfg->{use_ssl}) {
            $socket = IO::Socket::SSL->new(
            Proto    => 'tcp',
            PeerAddr => $cfg->{host} || 'localhost',
            PeerPort => $cfg->{port} || 993,
          ) or die $context->log(error => "create scoket error; $@");
    }

    $self->{imap} = Mail::IMAPClient->new(
        Socket   => $socket,
        User     => $cfg->{username},
        Password => $cfg->{password},
        Server   => $cfg->{host} || 'localhost',
        Port     => $cfg->{port} || 143,
      )
      or die $context->log(error => "Cannot connect; $@");
    $context->log(debug => "Connected IMAP-SERVER (" . $cfg->{host} . ")");
    $self->ensure_folder($context,$cfg->{folder},$cfg);

    if (!$cfg->{mailfrom}) {
        $cfg->{mailfrom} = 'plagger';
    }
}

sub finalize {
    my($self, $context, $args) = @_;
    my $cfg = $self->{conf};
    $self->{imap}->disconnect();
    if (my $msg_count = $self->{msg}) {
        $context->log(info => "Store $msg_count Message(s)");
    }
    $context->log(debug => "Disconnected IMAP-SERVER (" . $cfg->{host} . ")");
}

sub store_entry {
    my($self, $context, $args) = @_;
    my $cfg = $self->conf;

    my $msg = $self->prepare_entry($context, $args);

    my $folder = $self->folder_name($context, $args);

    $self->ensure_folder($context,$folder,$cfg);

    store_imap($self, $context,
               $msg->as_string(),
               $folder
           );

    $self->{msg} += 1;
}

sub store_imap {
    my($self, $context, $msg, $folder) = @_;
    $folder ||= 'INBOX';
    my $uid = $self->{imap}->append_string($folder, $msg, $self->conf->{mark})
      or die $context->log(error => "Could not append: $@");
}

1;

=head1 NAME

Plagger::Plugin::Publish::IMAP - Transmits IMAP server

=head1 SYNOPSIS

  - module: Publish::IMAP
    config:
      use_ssl: 1
      username: user
      password: passwd
      folder: plagger
      mailfrom: plagger@localhost
      mark: "\\Seen"

=head1 DESCRIPTION

This plug-in changes an entry into e-mail, and transmits it to an IMAP server.

=head1 AUTHOR

Nobuhito Sato

=head1 SEE ALSO

L<Plagger>

=cut

