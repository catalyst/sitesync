package App::SiteSync::Phase;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use File::Find qw();


=head1 NAME

App::SiteSync::Phase - Base class for sitesync phase runners

=cut


sub new {
    my($class, $app) = @_;

    return bless { app => $app }, $class;
}


sub app           { shift->{app}; }
sub work_root     { shift->app->work_root; }
sub site_work     { shift->app->site_work; }
sub site          { shift->app->site; }
sub site_name     { shift->app->site_name; }
sub source_url    { shift->app->source_url; }
sub source_domain { shift->app->source_domain; }
sub spider_dir    { shift->app->spider_dir; }
sub log           { shift->app->log(@_); }

sub each_file {
    my($self, $user_sub) = @_;

    return unless $user_sub;

    File::Find::find(
        {
            no_chdir  => 1,
            wanted    => sub { $user_sub->( $File::Find::name ); },
        },
        $self->source_domain
    );
}

1;

