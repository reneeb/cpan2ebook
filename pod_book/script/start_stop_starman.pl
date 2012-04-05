#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Spec;

my @ps        = `ps auwx`;
my @processes = grep{ m/starman .*? --listen .*? :3030/xms }@ps;

if ( $master ) {
    my @pids = map{ m/ \A .*? (\d+) /xms; $1 }@processes;

    if ( @pids ) {
        kill 9, @pids;
    }
}

my $dir = File::Spec->rel2abs( dirname __FILE__ );

chdir $dir;

my $command = 'starman --listen :3030';
#exec( $command );
exec( "nohup $command &" );
