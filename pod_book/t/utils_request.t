#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 11;

use CHI;
use File::Temp qw/ tempdir /;

my $dir = tempdir( CLEANUP => 1 );

###########################
# General module tests... #
###########################

my $module = 'PodBook::Utils::Request';
use_ok( $module );

my $obj = $module->new(
                        user_id => '127.0.0.1',
                        item_key => 'metacpan::EBook::MOBI',
                        item_type => 'mobi',
                        access_interval_limit => 0,
                        chi_ref => CHI->new( driver => 'File',
                                             root_dir => $dir )
                      );

isa_ok($obj, $module);

# methods
can_ok($obj, 'new');
can_ok($obj, 'clear_cache');
can_ok($obj, 'is_cached');

# fresh cache
$obj->clear_cache();
if ($obj->is_cached()) {
    fail('empty cache');
}
else {
    pass('empty cache');
}

# write to cache
my $book = 'This is ASCII, even if a real book is binary...';
$obj->cache_book( $book, 1);
if ($obj->is_cached()) {
    pass('cache hit');
}
else {
    fail('cache hit');
}

# cache entry is expired
sleep(2);
if ($obj->is_cached()) {
    fail('cache expired');
}
else {
    pass('cache expired');
}

# check protection of heavy load from one user
$obj->{uid_expiration} = 1;
if ($obj->uid_is_allowed()) {
    pass('user first request');
}
else {
    fail('user first request');
}
# user is to fast!
if ($obj->uid_is_allowed()) {
    fail('user block');
}
else {
    pass('user block');
}
# user waited long enough
sleep 2;
if ($obj->uid_is_allowed()) {
    pass('user second request');
}
else {
    fail('user second request');
}


# AT THE END, CLEAR ALL THE CACHE FROM TESTING!
$obj->clear_cache();
