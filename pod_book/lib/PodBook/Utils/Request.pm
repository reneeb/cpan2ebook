package PodBook::Utils::Request;

use strict;
use warnings;

our $VERSION = 0.1;

# Constructor of this class
sub new {
    my $self = shift;
    my %args = @_;

    my $ref = {
        # from interface
        args          => \%args,

        # internal variables
        book          => ''     ,
        cache         => $args{chi_ref} ,
        cache_key     => $args{item_key} . '--' . $args{item_type} ,
        uid_key       => 'UID:' . $args{user_id} ,
        uid_expiration=> $args{access_interval_limit},
        };

    bless($ref, $self);
    return $ref;
}

sub uid_is_allowed {
    my ($self) = @_;

    if($self->{cache}->is_valid($self->{uid_key})) {
        return 0;
    }
    else {
        $self->{cache}->set($self->{uid_key},
                            '',
                            $self->{uid_expiration},
                            );
        return 1;
    }
}

sub is_cached {

    my ($self) = @_;

    if($self->{cache}->is_valid($self->{cache_key})) {
        return 1;
    }
    else {
        return 0;
    }
}

# ONLY NEEDED FOR A COMPLETE CLEARANCE OF CACHE!
sub clear_cache {
    my ($self) = @_;

    return $self->{cache}->clear();
}

sub cache_book {
    my ($self, $book, $expires_in) = @_;

    $self->{cache}->set($self->{cache_key},
                        $book,
                        $expires_in,
                        );
}

sub get_book {
    my ($self) = @_;

    return $self->{cache}->get($self->{cache_key});

}

1;
