package PodBook::Perltuts;

# this is a controller
use Mojo::Base 'Mojolicious::Controller';

# the are the tools we need from CPAN
use Mojo::Headers;
use Mojo::UserAgent;
use Regexp::Common 'net';
use File::Temp 'tempfile';
use File::Slurp 'read_file';
use CHI;
use Encode;
use EPublisher;

sub list {
    my $self = shift;


    # lets load some values from the config file
    my $config            = $self->config;
    my $userblock_seconds = $config->{userblock_seconds};
    my $caching_seconds   = $config->{caching}->{seconds};
    my $tmp_dir           = $config->{tmp_dir};

    my $log = $self->app->log;

    # we need to know the version number in the template
    $self->stash( appversion => $PodBook::VERSION, listsize => 1, optional_message => '' );

    # get list of tutorials from cache
    my @tutorials = $self->_get_tutorial_list();

    $self->stash( tutorials => \@tutorials );

    # no book is requested - show list of tutorials
    unless ( $self->param('tutorial') ) {

        $self->render( message => '', optional_message => '' );
        return;
    }

    # check ebook format that is requested
    my $type = lc $self->param('format') || 'epub';
    
    if ( $type ne 'mobi' and $type ne 'epub' ) {

        $self->render( message => 'ERROR: Type of ebook unknown.' );
        $self->app->log->warn( 'Type (' . $type . ') of ebook unknown' );
        return;
    }

    # check if tutorial exists
    my $name = decode_utf8( $self->param('tutorial') );
    if ( !grep{ $name eq $_ }@tutorials ) {
        $self->render( message => 'ERROR: tutorial does not exist.' );
        $self->app->log->info( "tutorial $name does not exist" );
        return;
    }

    my $book_name = $name . '.' . $type;
    my $cached    = $self->_cache->get( $name . '_' . $type );

    # check if we have the book already in cache
    if ($cached) {

        # send the book to the client
        $self->send_download_to_client($cached, $book_name);
    }
    else {
        my ($fh, $filename) = tempfile(DIR => $tmp_dir, SUFFIX => '.book');
        unlink $filename; # we don't need the file, just the name of it

        # build the config for EPublisher
        my %config = ( 
            config => {
                perltuts => {
                    source => {
                        type    => 'PerltutsCom',
                        name    => $name,
                    },
                    target => { 
                        output => $filename,
                        author => "Perl",
                        # this option is ignored by "type: epub"
                        htmcover => "<h1>$name</h1><br />Downloaded from: <a href='http://perlybook.org'>perlybook.org</a><br />"
                    }   
                }   
            },  
            debug  => sub {
                print "@_\n";
            },  
        );

        # still building the config (and loading the right modules)
        if ($type eq 'mobi') {
            $config{config}{perltuts}{target}{type} = 'Mobi';
        }
        elsif ($type eq 'epub') {
            $config{config}{perltuts}{target}{type} = 'EPub';
        }
        else {
            # EXIT
            $self->render( message => 'ERROR: unknown book-type' );
        }

        my $publisher = EPublisher->new(
            %config,
            debug => sub{ $self->debug_epublisher( @_ ) },
        );
        
        # fetch from Perltuts.com and render
        $publisher->run( [ 'perltuts' ] );


        # TODO: EPublisher should give me the stuff as bin directly
        my $bin = read_file( $filename, { binmode => ':raw' } ) ;
        unlink $filename;

        # we finally have the EBook and cache it before delivering
        $self->_cache->set( $name . '_' . $type, $bin, { expires_in => $caching_seconds } );

        # send the EBook to the client
        $self->send_download_to_client($bin, $book_name);
    }

    # if we reach here... something is wrong!
    $self->render( message => 'Book cannot be delivered :-)' );
}

sub debug_epublisher {
    my ($self, $msg) = @_;

    my $debug_string = sprintf "[EPublisher][%s] %s", $$, $msg;
    $self->app->log->debug( $debug_string );
}

sub send_download_to_client {
    my ($self, $data, $name) = @_;

    $self->app->log->info("Sending for download: '$name'");

    $name = encode_utf8( $name );

    my $headers = Mojo::Headers->new();
    $headers->add(
        'Content-Type',
        "application/octet-stream; name=$name"
        #application/x-mobipocket-ebook would be for mobi specific...
    );
    $headers->add(
        'Content-Disposition',
        "attachment; filename=$name"
    );
    $headers->add('Content-Description','ebook');
    $self->res->content->headers($headers);

    $self->render_data($data);
}

sub _get_tutorial_list {
    my ($self) = @_;

    my $list = $self->_cache->get( 'Tutorials' ) || [];
    my @lists = map{ decode_utf8( $_ ) }@{$list};

    return @lists;
}

sub _cache {
    my ($self) = @_;

    my $config    = $self->config || { tmp_dir => '/tmp' };
    my $tmpdir    = $config->{tmp_dir};
    my $namespace = $config->{caching}->{perltuts};

    my $cache  = CHI->new(
        driver     => 'File',
        root_dir   => $tmpdir,
        namespace  => $namespace,
        serializer => 'Storable',
    );
}

1;
