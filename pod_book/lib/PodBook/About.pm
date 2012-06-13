package PodBook::About;

use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub list {
    my $self = shift;

    # this line is needed because otherwise "About" crashes
    my $listsize = $self->config->{autocompletion_size} || 10;
    if ( $listsize =~ /\D/ or $listsize > 100 ) {
        $listsize = 10;
    }

    $self->stash( listsize => $listsize );

    # we need to know the version number in the template
    $self->stash( appversion => $PodBook::VERSION );


    $self->render();
}

1;
