package App::SiteSync::Fixup;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';

use File::Slurp qw(read_file write_file);


=head1 NAME

App::SiteSync::Fixup - Handle the Fixup phase of a sitesync run

=cut


sub run {
    my($self) = @_;

    $self->fix_html_files;
}


sub fix_html_files {
    my($self) = @_;

    $self->each_file(sub {
        my($path) = @_;

        return unless $path =~ m{[.]html?(?:\?.*)?$};
        $_ = read_file($path);
        $self->fix_html($path) or return;
        write_file($path, $_);
    });
}


sub fix_html {
    my($self, $path) = @_;

    # Change %3F to ? in JS/CSS URLs
    s{([.](?:js|css))%3F}{$1?}g;

    # Remove domain portion from URLs in 

    my($host_prefix) = $self->source_url =~ m{^(https?://[^/]*)};
    s{(\@import\s+url\(")$host_prefix}{$1}g;

    return 1;
}

1;

