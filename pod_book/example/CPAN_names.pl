#!/usr/bin/perl

use YAML::Tiny;
use File::Basename;
use File::Spec;

use PodBook::Utils::CPAN::Names;

my $bin_dir = File::Spec->rel2abs( dirname __FILE__ );
 
 my $yaml    = YAML::Tiny->read(
     File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
     );

  
my $db_file  = $yaml->[0]->{cpan_namespaces_source};


my $t = PodBook::Utils::CPAN::Names->new('DB', $db_file);

print $t->translate_any2release('EBook::MOBI');
print "\n";

print $t->translate_any2release('EBook-MOBI');
print "\n";
