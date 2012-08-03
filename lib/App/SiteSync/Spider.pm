package App::SiteSync::Spider;

use 5.010;
use warnings;
use strict;
use autodie;
use Carp;

use parent 'App::SiteSync::Phase';

use POSIX qw( strftime );


=head1 NAME

App::SiteSync::Spider - Handle the spidering phase of a sitesync run

=cut


sub run {
    my($self) = @_;

    $self->log("Running wget against URL: " . $self->source_url);

    $self->rotate_spider_log;
    my $start_time = time();
    $self->run_wget;
    my $end_time = time();
    $self->remove_duplicates;
    $self->write_timestamps($start_time, $end_time);
}


sub rotate_spider_log {
    my($self) = @_;

    my $log = 'spider.log';
    return unless -e $log;
    system('savelog', '-q', $log);
}


sub run_wget {
    my($self) = @_;

    my @command = $self->wget_command;
    system(@command);
}


sub wget_command {
    my($self) = @_;

    my @command = $self->parse_wget_config;
    return @command if @command;

    my @extra_options = $self->parse_wget_options;

    @command = (
        'wget',
        '--recursive',
        '--level=inf',
        '--timestamping',
        '--html-extension',
        '--convert-links',
        '--backup-converted',
        '--no-verbose',
        '--restrict-file-names=unix,nocontrol',
        '--output-file=spider.log',
        @extra_options,
        '--domains=' . $self->source_domain,
        $self->source_url
    );
}


sub parse_wget_config {
    my($self) = @_;

    my $command = $self->site->{wget_command} or return;
    return $self->parse_parts($command);
}


sub parse_wget_options {
    my($self) = @_;

    my $options = $self->site->{wget_options} or return;
    return $self->parse_parts($options);
}


sub parse_parts {
    my($self, $string) = @_;

    return grep { defined } $string =~ m{(?:"((?:\\"|[^"])+)"|([^"\s]+)\s*)}g;
}


sub remove_duplicates {
    my($self) = @_;

    $self->each_file(sub {
        my($path) = @_;
        if( $path =~ m{[.]orig$} || $path =~ m{[.]1[.]html$} ) {
            unlink($path);
            return;
        }
        if( my($base_path) = $path =~ m{^(.*[.](?:js|css))\?} ) {
            if(-e $base_path) {
                unlink($path);
            }
            else {
                rename($path, $1);
            }
        }
    });
}


sub write_timestamps {
    my($self, $start_time, $end_time) = @_;

    $start_time = strftime('%F %T', localtime($start_time) );
    $end_time   = strftime('%F %T', localtime($end_time) );

    my $timestamp_file = $self->spider_dir . '/spidered.json';
    open my $out, '>', $timestamp_file;
    print $out <<"EOF";
{
    "start_time" : "$start_time",
    "end_time"   : "$end_time"
}
EOF
}




1;

