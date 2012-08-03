#!perl -T

use Test::More tests => 1;

use App::SiteSync;
use App::SiteSync::Spider;
use App::SiteSync::Fixup;
use App::SiteSync::Publish;


ok(1, "Successfully loaded App::SiteSync packages via 'use'");

diag( "Testing App::SiteSync $App::SiteSync::VERSION, Perl $], $^X" );
