package PodBook::About;

use Mojo::Base 'Mojolicious::Controller';

our $VERSION = 0.1;

# This action will render a template
sub form {
    my $self = shift;

    # this line is needed because otherwise "About" crashes
    my $listsize = $self->config->{autocompletion_size} || 10;
    if ( $listsize =~ /\D/ or $listsize > 100 ) {
        $listsize = 10;
    }

    $self->stash( listsize => $listsize );

    $self->render();
}

1;
