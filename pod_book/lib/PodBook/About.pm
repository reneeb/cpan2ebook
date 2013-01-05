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

    my @modules = qw(
        Mojolicious
        EPublisher
        EPublisher::Source::Plugin::MetaCPAN
        EPublisher::Source::Plugin::PerltutsCom
        EPublisher::Target::Plugin::EPub
        EPublisher::Target::Plugin::Mobi
        MetaCPAN::API
    );

    my @versions;
    for my $module ( @modules ) {
        eval "use $module";
        push @versions, { name => $module, version => $module->VERSION() };
    }
    $self->stash( versions => \@versions );


    $self->render();
}

1;
