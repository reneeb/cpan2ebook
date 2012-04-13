package PodBook::Utils::CPAN::Names::Source;

use strict;
use warnings;

use DBI;

# Constructor of this class
sub new {
    my (
        $self  , # object
        $type  , # type of source (not needed for the moment)
        $name  , # name of source
       ) = @_;

    my $db = DBI->connect("dbi:SQLite:$name", "", "",
                            {RaiseError => 1, AutoCommit => 1});

    my $ref = {
        db => $db,
    };

    bless($ref, $self);
    return $ref;
}

sub translate_any2release {
    my ($self, $q) = @_;

    my $res = $self->{db}->selectall_arrayref(
                            "SELECT release FROM names
                                WHERE module  = '$q'
                                OR    release = '$q'
                            ;");
    return $res->[0]->[0];
}

1;
