#!/usr/bin/perl

use strict;
use warnings;

use CHI;
use Mojo::UserAgent;
use YAML::Tiny;
use File::Basename;
use File::Spec;
use Encode;

my $ua = Mojo::UserAgent->new;
$ua->name( 'Perlybook - Perltuts scraper' );

my $base_url = 'http://perltuts.com';

my @languages = 
    map{ $_->{href} }
    $ua->get( $base_url )->res->dom( 'ul#languages > li > a' )->each;

my @tuts;
for my $lang ( @languages ) {
    $ua->get( $base_url . $lang );

    my @lang_tuts = 
        map{ my ($name) = $_ =~ m{/tutorials/ (.*?) \?format=pod }x; $name }
        grep{ /format=pod/ }
        $ua->get( $base_url . '/tutorials/' )->res->dom( 'div.column > ul > li > a' )->each;

    push @tuts, @lang_tuts;
}

my $file = File::Spec->catfile(
    dirname( __FILE__ ),
    '..',
    'pod_book',
    'config.yml',
);

die "config file $file does not exist!" if !-f $file;

my $yaml = YAML::Tiny->read( $file );

die "anything with YAML parsing went wrong!" if !$yaml;

my $tmpdir    = $yaml->[0]->{tmp_dir};
my $namespace = $yaml->[0]->{caching}->{perltuts};

my $cache  = CHI->new(
    driver     => 'File',
    root_dir   => $tmpdir,
    namespace  => $namespace,
    serializer => 'Storable',
);

$cache->set(
    'Tutorials',
    \@tuts,
    'never',
);

print "done\n";
