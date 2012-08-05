package App::SiteSync::Publish;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';


=head1 NAME

App::SiteSync::Publish - Handle the Publish phase of a sitesync run

=cut


sub run {
    my($self) = @_;
    $self->publish_to_targets;
}


sub publish_to_targets {
    my($self) = @_;
    my @targets = $self->list_targets;

    foreach my $target ( @targets ) {
        $self->{target_name} = $target->{name} || '<unnamed>';
        $self->publish_to_target( $target );
    }
}


sub target_name { shift->{target_name}; }


sub list_targets {
    my($self) = @_;

    my $targets = $self->site->{target};
    if($targets and @$targets) {
        return @$targets;
    }

    $self->log("No targets defined - skipping publish");
    return;
}


sub publish_to_target {
    my($self, $target) = @_;

    if($target->{rsync_target}) {
        return $self->rsync_to_target( $target );
    }
    $self->log("Don't know how to publish to '" . $self->target_name . "'");
}


sub rsync_to_target {
    my($self, $target) = @_;

    $self->log("rsyncing to '" . $self->target_name . "'");

    my @command = (
        'rsync', '--recursive', '--delete', 
    );

    if( $target->{rsync_secrets} ) {
        push @command, "--password-file=$target->{rsync_secrets}";
    }

    push @command, (
        $self->spider_dir . '/',  # Note, trailing slash is crucial
        $target->{rsync_target}
    );

    system( @command );
    if($? != 0) {
        my $status = $? >> 8;
        $self->log("rsync process exited with status: $status");
    }
}

1;

