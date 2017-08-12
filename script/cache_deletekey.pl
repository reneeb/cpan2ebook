#!/usr/bin/perl

use strict;
use warnings;

use CHI;
use YAML::Tiny;
use File::Spec;
use File::Basename;

my $bin_dir = File::Spec->rel2abs( dirname __FILE__ );
 
my $config    = YAML::Tiny->read(
    File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
);

my $cache_dir       = $config->[0]->{tmp_dir};
my $cache_namespace = $config->[0]->{caching}->{name};

# load the cache
my $cache = CHI->new(
    driver   => 'File',
    root_dir => $cache_dir,
    namespace=> $cache_namespace,
); 

my $key;
if (defined $ARGV[0]) {
    $key = $ARGV[0];
}
else {
    print "Please give a key as first argument\n";
    exit 1;
}

print scalar localtime;
print "\n";
print "remove key $key\n";
print "from cache: $cache_dir/$cache_namespace\n";
$cache->remove($key);
print scalar localtime;
print "\nDONE\n";

