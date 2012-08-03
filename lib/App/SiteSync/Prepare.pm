package App::SiteSync::Prepare;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';


=head1 NAME

App::SiteSync::Prepare - Handle the preparation phase of a sitesync run

=cut


sub run {
    my($self) = @_;
    $self->log("Preparing to spider site: " . $self->site->{name});
    $self->make_site_work;
    $self->clean_last_dir;
    $self->run_prepare_command
}


sub make_site_work {
    my($self) = @_;

    my $work_root = $self->work_root;

    die "Directory '$work_root' does not exist\n"
        unless -d $work_root;

    die "Directory '$work_root' is not writable\n"
        unless -w $work_root;

    if(!-d $self->site_work) {
        mkdir($self->site_work);
    }
}


sub clean_last_dir {
    my($self) = @_;

    my $spider_dir = $self->spider_dir;
    system('rm', '-rf', $spider_dir) if -d $spider_dir;
}


sub run_prepare_command {
    my($self) = @_;

    my $command = $self->site->{prepare_command} or return;
    system("$command");
    if($? != 0) {
        my $status = $? >> 8;
        $self->log("prepare_command exited with status: $status");
    }
}

1;


