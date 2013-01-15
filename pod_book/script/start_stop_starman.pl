#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Spec;

my $workers      = 10;
my $max_requests = 200;

my @ps        = `ps auwx`;
my @processes = grep{ m/starman .*? --listen .*? :3030/xms }@ps;

if ( @processes ) {
    my @pids = map{ m/ \A .*? (\d+) /xms; $1 }@processes;

    if ( @pids ) {
        kill 9, @pids;
    }
}

my $dir = File::Spec->rel2abs( dirname __FILE__ );

chdir $dir;

my $config = $ENV{POD_BOOK_CONFIG};
my $mode   = $ENV{MOJO_MODE};

my @exports;

push @exports, $config ? "export POD_BOOK_CONFIG=$config" : '';
push @exports, $mode ? "export MOJO_MODE=$mode" : '';

my $exports = join '', map{ $_ . ' && ' }@exports;

my $command = 'starman --listen :3030 --workers ' . $workers . ' --max-requests ' . $max_requests . ' --preload-app';
#exec( $command );
exec( "nohup $exports $command &" );
