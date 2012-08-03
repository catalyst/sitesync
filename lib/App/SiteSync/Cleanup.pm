package App::SiteSync::Cleanup;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';


=head1 NAME

App::SiteSync::Cleanup - Handle the cleanup phase of a sitesync run

=cut


sub run {
    my($self) = @_;
    $self->run_cleanup_command
}


sub run_cleanup_command {
    my($self) = @_;

    my $command = $self->site->{cleanup_command} or return;
    system("$command");
    if($? != 0) {
        my $status = $? >> 8;
        $self->log("cleanup_command exited with status: $status");
    }
}

1;


