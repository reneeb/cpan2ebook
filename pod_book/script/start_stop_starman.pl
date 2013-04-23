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

if ($config) {
    push @exports, "export POD_BOOK_CONFIG=$config";
}
if ($mode) {
    push @exports, "export MOJO_MODE=$mode";
}

# reminder for how to start the application
print "\nRunning app with the following settings:\n";
print "\tPOD_BOOK_CONFIG=$config\t# path to config\n";
print "\tMOJO_MODE=$mode\t\t# production | development\n";

my $exports = join '', map{ $_ . ' && ' }@exports;

my $command = 'starman --listen :3030 --workers ' . $workers . ' --max-requests ' . $max_requests . ' --preload-app';
#exec( $command );
exec( "$exports nohup $command &" );
