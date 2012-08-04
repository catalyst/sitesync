#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use autodie;
use Test::More;

use App::SiteSync;

my $app = App::SiteSync->new;
isa_ok($app, 'App::SiteSync');

@main::ARGV = qw(--config t/one-site.conf -p fixup -p publish);
eval {
    $app->parse_options;
    $app->load_config;
};
is("$@", '', 'parsed one-site.conf without error');

is(
    join(',', $app->all_phases),
    'prepare,spider,fixup,publish,cleanup',
    'default list of phases'
);

is(
    join(',', $app->selected_phases),
    'fixup,publish',
    'selected list of phases'
);


# test the proxy methods in the base class

$app->select_site;

$app->set_default_mappings;

my $prep_class = $app->load_class('prepare_runner');
is($prep_class, 'App::SiteSync::Prepare', 'prepare runner class');

my $phase = $prep_class->new($app);
isa_ok($phase, 'App::SiteSync::Prepare', 'prepare runner object');


is(
    $phase->site_name,
    'example',
    'site name'
);

is(
    $phase->site_work,
    '/var/lib/sitesync/example',
    'site_work'
);

is(
    $phase->source_url,
    'http://cms.example.com/',
    'source_url'
);

is(
    $phase->source_domain,
    'cms.example.com',
    'source_domain'
);

is(
    $phase->spider_dir,
    '/var/lib/sitesync/example/cms.example.com',
    'spider_dir'
);



done_testing;
