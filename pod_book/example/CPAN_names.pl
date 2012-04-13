#!/usr/bin/perl

use PodBook::Utils::CPAN::Names;

my $t = PodBook::Utils::CPAN::Names->new('DB', 'cpan_names.db');

print $t->translate_any2release('EBook::MOBI');
print "\n";

print $t->translate_any2release('EBook-MOBI');
print "\n";
