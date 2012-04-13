package PodBook::Utils::CPAN::Names;

use strict;
use warnings;

use YAML::Tiny;
use PodBook::Utils::CPAN::Names::Source;

# Constructor of this class
sub new {
    my (
        $self  , # object
       ) = @_;


    my $yaml = YAML::Tiny->new;
    $yaml = YAML::Tiny->read( 'config.yml' );
    my $src_name = $yaml->[0]->{cpan_namespaces_source};

    my $source = PodBook::Utils::CPAN::Names::Source->new('DB',$src_name);

    my $ref = {
        source => $source,
    };

    bless($ref, $self);
    return $ref;
}

sub translate_any2release {
    my ($self,$q) = @_;

    return $self->{source}->translate_any2release($q);
}

1;
