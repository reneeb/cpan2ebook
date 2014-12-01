#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 9;
use Test::Mojo;

# mock environment variable
$ENV{POD_BOOK_CONFIG} = './t/files/testconfig.yml';

use_ok 'PodBook';

# Test
my $t = Test::Mojo->new('PodBook');
$t->get_ok('/')->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_like(qr/search/i);
$t->get_ok('/about')->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_like(qr/About/i);
