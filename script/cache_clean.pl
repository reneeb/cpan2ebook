#!/usr/bin/perl

use strict;
use warnings;

############################################################
# The CHI module does not automatically clean up the cache #
# so we do it with a cronjob                               #
############################################################

use CHI;
use YAML::Tiny;
use File::Spec;
use File::Basename;

my $bin_dir = File::Spec->rel2abs( dirname __FILE__ );
 
my $yaml    = YAML::Tiny->read(
    File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
);

die "cannot read YAML" if !$yaml;

my $config = $yaml->[0] || {};

for my $key ( keys %{ $config->{CHI} } ) {

    my $cache_config = $config->{CHI}->{$key};
    next if @ARGV and !grep{ $key eq $_ }@ARGV;
    
    # load the cache
    my $cache = CHI->new(
        %{$cache_config},
        namespace=> $key,
    ); 
    
    print scalar localtime;
    print " - remove old data from cache $key\n";
    $cache->purge();
}

print scalar localtime;
print " - DONE\n";

