package PodBook;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Documentation browser under "/perldoc" (this plugin requires Perl 5.10)
  #$self->plugin('pod_renderer');

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/welcome')->to('example#welcome');
  $r->route('/')      ->to('cpan_search#form');
  $r->route('/upload')->to('upload#form');

}

1;
