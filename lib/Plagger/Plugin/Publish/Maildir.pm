package Plagger::Plugin::Publish::Maildir;
use strict;
use base qw( Plagger::Plugin::Publish::Email );

use Encode qw/ from_to encode/;
use File::Find;
BEGIN { eval { require Encode::IMAPUTF7 } }

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'plugin.init'      => \&initialize,
        'publish.entry'    => \&store_entry,
        'publish.finalize' => \&finalize,
    );
}

sub rule_hook { 'publish.entry' }

sub ensure_folder {
    my ($context,$maildir,$folder,$cfg)=@_;

    my $permission = ( $cfg->{permission} ? oct($cfg->{permission}) : 0700 );

    my $path = "$maildir/.$folder";
    $path =~ s/\/\//\//g;
    $path =~ s/\/$//g;
    $path=encode($cfg->{folder_encoding} || 'IMAP-UTF-7',$path);
    unless (-d $path) {
        mkdir($path, $permission)
            or die $context->log(error => "Could not create $path");
        $context->log(info           => "Create new folder ($path), permission $permission");
    }
    unless (-d $path . "/new") {
        mkdir($path . "/new", $permission)
            or die $context->log(error => "Could not Create $path/new");
        $context->log(info           => "Create new folder($path/new)");
    }

    return $path;
}

sub initialize {
    my($self, $context, $args) = @_;
    my $cfg = $self->conf;
    if (-d $cfg->{maildir}) {
        $self->{path} = ensure_folder($context, $cfg->{maildir},$cfg->{folder}, $cfg);
    }
    else {
        die $context->log(error => "Could not access $cfg->{maildir}");
    }
}

sub finalize {
    my($self, $context, $args) = @_;
    if (my $msg_count = $self->{msg}) {
        if (my $update_count = $self->{update_msg}) {
            $context->log(info =>
"Store $msg_count message(s) ($update_count message(s) updated)"
            );
        }
        else {
            $context->log(info => "Store $msg_count message(s)");
        }
    }
}

sub store_entry {
    my($self, $context, $args) = @_;
    my $cfg = $self->conf;

    my $msg = $self->prepare_entry($context, $args);

    local $self->{path} = ensure_folder($context,
                                        $cfg->{maildir},
                                        $self->folder_name($context,$args),
                                        $cfg);
    store_maildir($self, $context, $msg->as_string(), $id);

    $self->{msg} += 1;
}

sub store_maildir {
    my($self, $context, $msg, $id) = @_;
    my $filename = $id . ".plagger";
    find(
        sub {
            if ($_ =~ m!$id.*!) {
                unlink $_;
                $self->{update_msg} += 1;
            }
        },
        $self->{path} . "/cur"
    );
    $context->log(debug => "writing: new/$filename");
    my $path = $self->{path} . "/new/" . $filename;
    open my $fh, ">", $path or $context->error("$path: $!");
    print $fh $msg;
    close $fh;
}

1;

=head1 NAME

Plagger::Plugin::Publish::Maildir - Store Maildir

=head1 SYNOPSIS

  - module: Publish::Maildir 
    config:
      maildir: /home/foo/Maildir
      folder: plagger
      attach_enclosures: 1
      mailfrom: plagger@localhost

=head1 DESCRIPTION

This plugin changes an entry into e-mail, and saves it to Maildir.

=head1 AUTHOR

Nobuhito Sato

=head1 SEE ALSO

L<Plagger>

=cut

