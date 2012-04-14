package PodBook::About;

use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub form {
    my $self = shift;

    $self->render();
}

1;
