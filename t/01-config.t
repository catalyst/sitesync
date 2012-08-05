#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use autodie;
use Test::More;

use App::SiteSync;

my $app = App::SiteSync->new;
isa_ok($app, 'App::SiteSync');

eval { $app->load_config; };
like(
    $@,
    qr{/etc/sitesync.conf},
    'app is looking for /etc/sitesync.conf by default'
);


# Read the "one-site.conf" file

@main::ARGV = qw(--config t/one-site.conf --target PROD);
eval {
    $app->parse_options;
    $app->load_config;
};
is("$@", '', 'parsed one-site.conf without error');

is(
    $app->work_root,
    '/var/lib/sitesync',
    'default work_root'
);

eval {
    $app->select_site;
};
is("$@", '', 'selected the only available site implicitly');

is(
    $app->site_name,
    'example',
    'site name'
);

is(
    $app->site_work,
    '/var/lib/sitesync/example',
    'site_work'
);

is(
    $app->source_url,
    'http://cms.example.com/',
    'source_url'
);

is(
    $app->source_domain,
    'cms.example.com',
    'source_domain'
);

is(
    $app->spider_dir,
    '/var/lib/sitesync/example/cms.example.com',
    'spider_dir'
);

# Check initial, unfiltered, target list

is(
    target_names($app),
    'UAT, PROD, DR',
    'all available targets'
);

eval {
    $app->select_targets;
};
is("$@", '', 'selected targets without error');

is(
    target_names($app),
    'PROD',
    'target list now filtered to one selection'
);

@main::ARGV = qw(--config t/one-site.conf --target UAT --target PROD);
eval {
    $app->parse_options;
    $app->load_config;
    $app->select_site;
    $app->select_targets;
};
is("$@", '', 're-parsed one-site.conf without error');

is(
    target_names($app),
    'UAT, PROD',
    'target list now filtered to two selections'
);

# Read the "two-sites.conf" file

@main::ARGV = qw(--config t/two-sites.conf);
$app = App::SiteSync->new;
eval {
    $app->parse_options;
    $app->load_config;
};
is("$@", '', 'parsed two-sites.conf without error');

eval {
    $app->select_site;
};
like(
    "$@",
    qr{must.*specify.*site},
    "can't implicitly select a site"
);

like(
    "$@",
    qr{Available sites: example, campaign},
    "error message lists available sites"
);

@main::ARGV = qw(--config t/two-sites.conf --site campaign --target UAT);
$app = App::SiteSync->new;
eval {
    $app->parse_options;
    $app->load_config;
    $app->select_site;
};
is("$@", '', 'parsed two-sites.conf and selected site without error');

is(
    $app->site_name,
    'campaign',
    "correct site was selected using --site option"
);

is(
    $app->work_root,
    '/var/projects/campaign/sitesync',
    "site-specific work_root"
);

eval {
    $app->select_targets;
};
like(
    "$@",
    qr{No .*target.*'UAT'.*in.*config},
    "target 'UAT' was not valid"
);
like(
    "$@",
    qr{Available targets: <none defined>},
    "no targets available"
);

@main::ARGV = qw(--config t/two-sites.conf --site campaign);
$app = App::SiteSync->new;
eval {
    $app->parse_options;
    $app->load_config;
    $app->select_site;
    $app->select_targets;
};
is("$@", '', 'selected default targets without errors');

is(
    target_names($app),
    '',
    'no targets defined for this <site>'
);

done_testing;

exit;


sub target_names {
    my($app) = @_;

    return join ', ', map { $_->{name} || '<unnamed>' } $app->targets;
}
