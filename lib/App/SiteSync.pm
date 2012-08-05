package App::SiteSync;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;


=head1 NAME

App::SiteSync - Spider a site from a CMS to static files

=cut


use Config::General;
use Getopt::Long qw(GetOptions);
use Pod::Usage;
use Data::Dumper;

my @all_phases = qw( prepare spider fixup publish cleanup );

my $default_mappings = {
    app             => 'App::SiteSync',
    prepare_runner  => 'App::SiteSync::Prepare',
    spider_runner   => 'App::SiteSync::Spider',
    fixup_runner    => 'App::SiteSync::Fixup',
    publish_runner  => 'App::SiteSync::Publish',
    cleanup_runner  => 'App::SiteSync::Cleanup',
};

my $default_config_file = '/etc/sitesync.conf';
my $default_work_root   = '/var/lib/sitesync';


sub run {
    my $class = shift;
    my $self = $class->new;
    $self->parse_options;
    if($self->opt('help')) {
        $self->show_pod;
        exit;
    }
    $self->load_config;
    $self->set_default_mappings();
    $self->select_site;

    chdir($self->site_work);

    $self->run_phases;
}


sub new {
    my $class = shift;
    return bless { @_ }, $class;
}


sub parse_options {
    my($self) = @_;

    my(%opt) = ( phase => [] );
    if(!GetOptions(\%opt, $self->getopt_spec)) {
        $self->die_usage();
    }
    $self->{opt} = \%opt;
}


sub getopt_spec {
    my($self) = @_;
    return('help|?', 'config|c=s', 'list-phases|l', 'phase|p=s', 'site|s=s');
}


sub die_usage {
    my($self, $message) = @_;

    warn "$message\n" if $message;
    pod2usage(-exitval => 1,  -verbose => 0);
}


sub show_pod {
    my($self) = @_;
    pod2usage(-exitval => 0,  -verbose => 2);
}


sub opt {
    my($self, $key, $default) = @_;

    return $self->{opt}->{$key} // $default;
}


sub load_config {
    my($self) = @_;

    my $config_file = $self->opt('config', $default_config_file);
    my %config = Config::General->new($config_file)->getall;

    # Make sure {site} is a list even if only one
    if($config{site}) {
        if(ref($config{site}) eq 'HASH') {
            $config{site} = [ $config{site} ];
        }

        # Make sure {target} is a list even if only one
        foreach my $site ( @{ $config{site} } ) {
            if($site && ref($site->{target}) eq 'HASH') {
                $site->{target} = [ $site->{target} ];
            }
        }
    }

    $config{work_root}      //= $default_work_root;
    $config{class_mappings} //= {};

    $self->{config} = \%config;
}


sub config {
    my($self, $key, $default) = @_;
    return $self->{config}->{$key} // $default;
}


sub set_default_mappings {
    my($self, $mappings) = @_;

    $mappings ||= $default_mappings;

    my $map = $self->config('class_mappings');
    while(my($key, $class) = each %$mappings) {
        $map->{$key} //= $class;
    }
}


sub select_site {
    my($self) = @_;

    my $sites = $self->config('site', []);
    my $site_names = join ', ', map {
        $_->{name} || die "Config file contains <site> with no name\n";
    } @$sites;

    die "No <site> sections in config file\n" unless @$sites;

    if( my $name = $self->opt('site') ) {
        if( my($site) = grep { $_->{name} eq $name } @$sites ) {
            $self->{site} = $site;
        }
        else {
            die "No <site> section named '$name' in config file.\n"
                . "Available sites: $site_names\n";
        }
    }
    elsif(@$sites == 1) {
        $self->{site} = $sites->[0];
    }
    else {
        die "You must specify which <site> to spider/publish.\n"
            . "Available sites: $site_names\n";
    }

    $self->extract_domain;
    $self->{site_work}  = $self->work_root . '/' . $self->site->{name};
    $self->{spider_dir} = $self->site_work . '/' . $self->source_domain;

    my %onsite_domain = (
        $self->source_domain => 1,
    );
    if(my $alias = $self->{site}->{domain_alias}) {
        $alias = [ $alias ] unless ref($alias);
        $onsite_domain{$_} = 1 foreach @$alias;
    }
    $self->{onsite_domain} = \%onsite_domain;
}


sub work_root {
    my($self) = @_;

    if(my $site = $self->site) {
        if(my $work_root = $site->{work_root}) {
            return $work_root;
        }
    }
    return $self->config('work_root');
}


sub site          { shift->{site}; }
sub source_url    { shift->site->{source_url}; }
sub source_domain { shift->{source_domain}; }
sub site_name     { shift->site->{name}; }
sub site_work     { shift->{site_work}; }
sub spider_dir    { shift->{spider_dir}; }


sub extract_domain {
    my($self) = @_;

    my $source_url = $self->source_url
        or die "Can't find 'source_url' for site '" . $self->site_name . "'\n";

    my($domain) = $source_url =~ m{^https?://([^/]+)}
        or die "Malformed URL: $source_url\n";

    $self->{source_domain} = $domain;
}


sub onsite_domain {
    my($self, $domain) = @_;
    return $self->{onsite_domain}->{$domain};
}


sub run_phases {
    my($self) = @_;

    my $list_only = $self->opt('list-phases');
    my @phases = $self->selected_phases;
    @phases = $self->all_phases if !@phases;

    foreach my $phase ( @phases ) {
        if($list_only) {
            print "Phase: $phase\n";
            next;
        }
        $self->log("Running phase: $phase");
        my $class_key = "${phase}_runner";
        my $runner = $self->load_class($class_key);
        $runner->new($self)->run;
    }
    $self->log("Complete") unless $list_only;
}


sub all_phases {
    return @all_phases;
}


sub selected_phases {
    my($self) = @_;

    my $selected_phases = $self->opt('phase');
    return unless @$selected_phases;

    my %valid = map { $_ => 1 } $self->all_phases;
    foreach my $phase ( @$selected_phases ) {
        die "Unrecognised phase '$phase'\n" unless $valid{$phase};
    }

    my %want = map { $_ => 1 } @$selected_phases;
    return grep { $want{$_} } $self->all_phases;
}


sub load_class {
    my($self, $class_key) = @_;

    my $class = $self->{config}->{class_mappings}->{$class_key}
        or croak "Can find class mapping for '$class_key'";

    my $path = "$class.pm";
    $path =~ s{::}{/}g;
    require $path;

    return $class;
}


sub log {
    my($self, $message) = @_;

    print "$message\n";
}


1;

__END__

=head1 SYNOPSIS

Usually invoked from the sitesync wrapper script like this:

    use App::SiteSync;

    App::SiteSync->run

=head1 DESCRIPTION

The package provides a framework for:

=over 4

=item *

invoking wget to spider a site to static files

=item *

applying 'fixups' to the files

=item *

rsyncing the resulting files to one or more target servers/directories

=back

=head1 METHODS

=head1 COPYRIGHT 

Copyright (c) 2012 Catalyst IT

Author: Grant McLean E<lt>Grant McLeanE<gt>

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

