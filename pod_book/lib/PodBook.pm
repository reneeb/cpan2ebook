package PodBook;

use strict;
use warnings;

use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/')      ->to('cpan_search#form');
  $r->route('/upload')->to('upload#form');

}

1;
