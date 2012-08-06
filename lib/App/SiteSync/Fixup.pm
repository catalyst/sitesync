package App::SiteSync::Fixup;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';


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
        $_ = $self->read_file($path);
        $self->fix_html($path) or return;
        $self->write_file($path, $_);
    });
}


sub read_file {
    my($self, $path) = @_;

    open my $fh, '<', $path;
    local($/);
    return <$fh>;
}


sub write_file {
    my($self, $path, $content) = @_;

    open my $fh, '>', $path;
    print $fh $content;
    close($fh);
}


sub fix_html {
    my($self, $path) = @_;

    # Apply link fixups to HREF and SRC attributes
    s{(<\w[^>]+\b(?:href|src)=)(['"])(.+?)\2}
     {$1 . $2 . $self->fix_link($3) . $2}isge;

    # Apply link fixups to URLs in CSS imports
    s{(\@import\s+url\()(['"]|)(.+?)\2\)}
     {$1 . $2 . $self->fix_link($3) . $2 . ')'}isge;

    return 1;
}


sub fix_link {
    my($self, $url) = @_;

    # Return offsite links unchanged
    if( my($domain, $rest) = $url =~ m{https?://([^/]+)(.*)$} ) {
        return $url unless $self->onsite_domain($domain);
        # Strip domain portion of onsite links
        $url = $rest // '/';
        $url = '/' unless length $url;
    }

    # Strip trailing index.html
    $url =~ s{index[.]html?(#.*|)$}{$1};

    # Fix %3F => ? in cache-busting query suffix on JS/CSS
    $url =~ s{([.](?:js|css))%3F}{$1?}i;

    return $url;
}

1;

