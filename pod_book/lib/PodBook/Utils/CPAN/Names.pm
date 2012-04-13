package PodBook::Utils::CPAN::Names;

use strict;
use warnings;

use File::Basename;
use File::Spec;
use YAML::Tiny;
use PodBook::Utils::CPAN::Names::Source;

# Constructor of this class
sub new {
    my (
        $self  , # object
       ) = @_;


    my $bin_dir = File::Spec->rel2abs( dirname __FILE__ );
    my $yaml    = YAML::Tiny->read(
        File::Spec->catfile( $bin_dir, '..', 'config.yml' ),
        );
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
