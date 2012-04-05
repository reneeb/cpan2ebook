#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Spec;

my @ps       = `ps auwx`;
my ($master) = grep{ m/master .*? --listen .*? :3030/xms }@ps;

if ( $master ) {
    my ($pid) = $master =~ m/ \A .*? (\d+) /xms;

    if ( $pid ) {
        kill 9, $pid;
    }
}

my $dir = File::Spec->rel2abs( dirname __FILE__ );

chdir $dir;

my $command = 'starman --listen :3030';
exec( $command );
#exec( "nohup $command &" );
