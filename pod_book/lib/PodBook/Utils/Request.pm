package PodBook::Utils::Request;

use strict;
use warnings;

use CHI;         # for file caching
use File::Spec;  # for cross platform temp dir

our $VERSION = 0.1;

# Constructor of this class
sub new {
    my (
        $self  , # object
        $uid   , # user id
        $source, # identifier (metacpan::modulename/upload)
        $type  , # mobi/epub
        $uid_expiration,
        $cache_namespace,
        $cache_dir,
       ) = @_;

    # check the arguments!
    unless (defined $cache_namespace) {
        $cache_namespace = 'Mojolicious-PodBook-Request';
    }
    unless ($source =~ /^upload/ or $source =~ /^metacpan::/) {
        die ("Invalid source: $source");
    }

    unless (defined $cache_dir) {
        $cache_dir = File::Spec->tmpdir();
    }
    unless (defined $uid_expiration) {
        $uid_expiration = 2;
    }

    # this gives me a path for temporary file storage, depending on OS

    # load the cache
    my $cache = CHI->new(
        driver   => 'File',
        root_dir => $cache_dir,
        namespace=> $cache_namespace,
    );

    my $ref = {
        # from interface
        uid           => $uid   ,
        source        => $source,
        type          => $type  ,

        # internal variables
        pod           => ''     ,
        book          => ''     ,
        cache         => $cache ,
        cache_key     => "$source--$type",
        uid_key       => "UID:$uid",
        uid_expiration=> $uid_expiration,

        # state variables
        is_cached     => 0      ,
        pod_loaded    => 0      ,
        book_rendered => 0      ,
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

    if($self->{source} =~ /^upload/) {
        # upload content is never cached
        return 0;
    }

    if($self->{cache}->is_valid($self->{cache_key})) {
        $self->{is_cached} = 1; # true
        return 1;
    }
    else {
        $self->{is_cached} = 0; # false
        return 0;
    }
}

# ONLY NEEDED FOR A COMPLETE CLEARANCE OF CACHE!
sub clear_cache {
    my ($self) = @_;

    return $self->{cache}->clear();
}

sub cache_book {
    my ($self, $expires_in) = @_;

    $self->{cache}->set($self->{cache_key},
                        $self->{book},
                        $expires_in,
                        );
}

sub load_pod {

    my ($self) = @_;

    # fetch POD into global VAR
}

sub set_book {

    my ($self, $book) = @_;

    $self->{book} = $book;
}

sub get_book {
    my ($self) = @_;

    return $self->{cache}->get($self->{cache_key});

}

1;
