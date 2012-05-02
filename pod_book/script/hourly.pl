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
 
my $config    = YAML::Tiny->read(
    File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
);

my $cache_dir       = $config->[0]->{tmp_dir};
my $cache_namespace = $config->[0]->{caching_name};

# load the cache
my $cache = CHI->new(
    driver   => 'File',
    root_dir => $cache_dir,
    namespace=> $cache_namespace,
); 

print scalar localtime;
print " - remove old data from cache: $cache_dir/$cache_namespace\n";
$cache->purge();
print scalar localtime;
print " - DONE\n";

