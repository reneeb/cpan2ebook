package PodBook::Upload;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub form {
    my $self = shift;
    
    if ($self->param('in_text')) {
        $self->render( message => 'button pressed' );
    }
    else {
        $self->render( message => '' );
    }
}

1;
