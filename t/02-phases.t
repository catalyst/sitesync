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


done_testing;
