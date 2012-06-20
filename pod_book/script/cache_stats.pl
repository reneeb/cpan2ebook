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
my $cache_namespace = $yaml->[0]->{caching}->{name};

# load the cache
my $cache = CHI->new(
    driver   => 'File',
    root_dir => $cache_dir,
    namespace=> $cache_namespace,
); 

print "Should I purge all expired keys from the cache?\n";
print "This operation may take a while and need some server load.\n";
print "Type 'y' or 'Yes' to accept, 'q' or empty to skip: ";
my $continue = <STDIN>;
chomp $continue;
if ($continue =~ /y{1}e?s?/i) {
    print 'cleanup keys...';
    $cache->purge();
    print "DONE\n";
}

my @keys = $cache->get_keys();

# if option --keys is set we print the original keys!
if (defined $ARGV[0] and $ARGV[0] eq '--keys') {
    print join "\n", @keys;
    print "\n";
    exit 0;
}

my @uid     = ();
my @release = ();
my @unknown =();
foreach my $key (@keys) {
    if ($key =~ m/^UID:([\d\.]+)$/) {
        push (@uid, $1);
    }
    elsif ($key =~ m/^metacpan::(.*)/) {
        push (@release, $1);
    }
    else {
        push (@unknown, $key);
    }
}

print "\n# " . @uid . " IP addresses found:\n";
print join ("\n", (sort @uid));
print "\n";

print "\n# " . @release . " releases found:\n";
print join ("\n", (sort @release));
print "\n";

print "\n# " . @unknown . " unknown found:\n";
print join ("\n", (sort @unknown));
print "\n";

