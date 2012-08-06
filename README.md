Sitesync
========

Sitesync provides a configurable framework to automate the process of:

* invoking wget to spider a web site to static files
* applying 'fixups' to the files
* rsyncing the resulting files to one or more target servers/directories

Common use-cases include 'publishing' a site from a CMS to static files; or taking a snapshot of a site for backup/disaster recovery purposes.

For details of available command-line options and recognised configuration parameters, see:

    bin/sitesync --help

The process of spidering and publishing the site is broken down into these phases: prepare, spider, fixup, publish, cleanup.  Each phase is implemented as a Perl class which can be overridden with your own custom code.  There are also a couple of config hooks for running user-supplied scripts in the prepare and cleanup phases.

Copyright
=========

Sitesync is copyright (C) 2012 Catalyst IT.
