package PodBook::About;

use Mojo::Base 'Mojolicious::Controller';

our $VERSION = 0.1;

# This action will render a template
sub form {
    my $self = shift;

    # this line is needed because otherwise "About" crashes
    $self->stash( listsize => 0 );

    $self->render();
}

1;
