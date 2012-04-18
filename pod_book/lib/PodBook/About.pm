package PodBook::About;

use Mojo::Base 'Mojolicious::Controller';

our $VERSION = 0.1;

# This action will render a template
sub form {
    my $self = shift;

    $self->render();
}

1;
