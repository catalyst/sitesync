#!/usr/bin/perl

use 5.010;
use strict;
use warnings;
use autodie;
use Test::More;

use App::SiteSync;

my $app = App::SiteSync->new;
isa_ok($app, 'App::SiteSync');

@main::ARGV = qw(--config t/one-site.conf);
$app->parse_options;
$app->load_config;
$app->select_site;
$app->set_default_mappings;

my $fixup_class = $app->load_class('fixup_runner');
is($fixup_class, 'App::SiteSync::Fixup', 'fixup runner class');

my $fixup = $fixup_class->new($app);
isa_ok($fixup, 'App::SiteSync::Fixup', 'fixup runner object');


# Test link fixup method

is(
    $fixup->fix_link('http://google.com/index.html'),
    'http://google.com/index.html',
    'offsite links are not affected'
);

is(
    $fixup->fix_link('http://cms.example.com/about-us.html'),
    '/about-us.html',
    'links to source domain have domain portion stripped'
);

is(
    $fixup->fix_link('http://www.example.com/about-us.html'),
    '/about-us.html',
    'aliased domain is stripped too'
);

is(
    $fixup->fix_link('http://example.com/about-us.html'),
    '/about-us.html',
    'another aliased domain is stripped too'
);

is(
    $fixup->fix_link('http://cms.example.com/'),
    '/',
    'scheme://domain is stripped to slash if no other path'
);

is(
    $fixup->fix_link('http://cms.example.com'),
    '/',
    'scheme://domain is replaced with slash if no path at all'
);

is(
    $fixup->fix_link('http://cms.example.com/index.html'),
    '/',
    'trailing "index.html" is stripped'
);

is(
    $fixup->fix_link('/index.html'),
    '/',
    'trailing "index.html" from root relative link'
);

is(
    $fixup->fix_link('index.html'),
    './',
    'bare "index.html" converted to "./"'
);

is(
    $fixup->fix_link('http://cms.example.com/index.htm'),
    '/',
    'trailing "index.htm" is stripped too'
);

is(
    $fixup->fix_link('http://cms.example.com/index.html#target'),
    '/#target',
    '"index.html" is stripped from before fragment too'
);

is(
    $fixup->fix_link('http://cms.example.com/style.css%3FRANDOM-STRING'),
    '/style.css?RANDOM-STRING',
    'cache-busting suffix was fixed on CSS link'
);

is(
    $fixup->fix_link('http://cms.example.com/jquery.js%3FRANDOM-STRING'),
    '/jquery.js?RANDOM-STRING',
    'cache-busting suffix was fixed on JS link'
);

is(
    $fixup->fix_link('/jquery.js%3FRANDOM-STRING'),
    '/jquery.js?RANDOM-STRING',
    'cache-busting suffix was fixed on root-relative JS link'
);

is(
    $fixup->fix_link('http://cms.example.com/page.html%3FRANDOM-STRING'),
    '/page.html%3FRANDOM-STRING',
    '%3F fixup was not applied to HTML link'
);


# Test HTML fixup method

sub fix_html {
    $_ = shift;
    my $path = shift || '/index.html';
    $fixup->fix_html($path);
    return $_;
}

is(
    fix_html('<p>http://cms.example.com/</p>'),
    '<p>http://cms.example.com/</p>',
    'URL in text content was unchanged'
);

is(
    fix_html('<p><a href="http://cms.example.com/">Home</a></p>'),
    '<p><a href="/">Home</a></p>',
    'URL in link attribute was fixed'
);

is(
    fix_html('<link rel="stylesheet" href="http://cms.example.com/style.css">'),
    '<link rel="stylesheet" href="/style.css">',
    'URL in link element was fixed'
);

is(
    fix_html('<p><img src="http://cms.example.com/logo.png"></p>'),
    '<p><img src="/logo.png"></p>',
    'URL in image src attribute was fixed'
);

is(
    fix_html('<script src="http://cms.example.com/site.js%3F1344121323">'),
    '<script src="/site.js?1344121323">',
    'cache-busting suffix in script src attribute was fixed'
);

is(
    fix_html(
        qq{<map name="peoplemap">\n}
        . qq{<area href="http://cms.example.com/people/tom.htm" />\n}
        . qq{<area href="http://cms.example.com/people/dick.htm" />\n}
        . qq{<area href="http://cms.example.com/people/larry.htm" />\n}
        . qq{</map>\n}
    ),
    qq{<map name="peoplemap">\n}
    . qq{<area href="/people/tom.htm" />\n}
    . qq{<area href="/people/dick.htm" />\n}
    . qq{<area href="/people/larry.htm" />\n}
    . qq{</map>\n},
    'multiple URLs in image map area tags were fixed'
);

is(
    fix_html(
        qq{<style>\n}
        . qq{\@import url("http://cms.example.com/system.css%3Fm7y7pq");\n}
        . qq{\@import url("http://cms.example.com/plugin.css%3Fm7y7pq");\n}
        . qq{</style>\n},
    ),
    qq{<style>\n}
    . qq{\@import url("/system.css?m7y7pq");\n}
    . qq{\@import url("/plugin.css?m7y7pq");\n}
    . qq{</style>\n},
    'multiple URLs in style tag @imports were fixed'
);

done_testing();

