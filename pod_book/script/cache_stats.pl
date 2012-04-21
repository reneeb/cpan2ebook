#!/usr/bin/perl

use strict;
use warnings;

use CHI;
use YAML::Tiny;
use File::Spec;
use File::Basename;

my $bin_dir = File::Spec->rel2abs( dirname __FILE__ );
 
my $yaml    = YAML::Tiny->read(
    File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
);

$| = 1;

my $cache_dir       = $yaml->[0]->{tmp_dir};
my $cache_namespace = $yaml->[0]->{caching_name};

# load the cache
my $cache = CHI->new(
    driver   => 'File',
    root_dir => $cache_dir,
    namespace=> $cache_namespace,
); 

print "Should I purge all expired keys from the cache?\n";
print "This operation may take a while and need some server load.\n";
print "Type 'y' or 'Yes' to accept, or 'q' to deny: ";
my $continue = <STDIN>;
chomp $continue;
if ($continue =~ /[yY]{1}e?s?/) {
    $cache->purge();
}

my @keys = $cache->get_keys();

print sort join "\n", @keys;
print "\n";

