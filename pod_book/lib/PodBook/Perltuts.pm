package PodBook::Perltuts;

# this is a controller
use Mojo::Base 'Mojolicious::Controller';

# the are the tools we need from CPAN
use Mojo::Headers;
use Mojo::UserAgent;
use File::Temp 'tempfile';
use File::Slurp 'read_file';
use Encode;
use EPublisher;
use Regexp::Common 'net';

use PodBook::Utils::Request;

sub list {
    my $self = shift;


    # lets load some values from the config file
    my $config            = $self->config;
    my $cache_name        = 'PerltutsCom';
    my $caching_seconds   = $config->{cache_expiration}->{seconds};
    my $tmp_dir           = $config->{tmp_dir};
    my $userblock_seconds = $config->{userblock_seconds};

    my @tutorials = @{$config->{PerltutsCom}->{tut_name}};

    my $log = $self->app->log;

    # we need to know the version number in the template
    $self->stash( appversion => $PodBook::VERSION, listsize => 1, optional_message => '' );


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
        $self->render(message => "ERROR: tutorial $name does not exist.");
        $self->app->log->info( "tutorial $name does not exist" );
        return;
    }

    my $book_name = $name . '.' . $type;

    my $book_request = PodBook::Utils::Request->new(
        user_id               => $self->tx->remote_address,
        item_key              => $name,
        item_type             => $type,
        access_interval_limit => $userblock_seconds,
        chi_ref               => $self->chi($cache_name), # CHI file-cache
    );  

    # we check if the user is using the page to fast
    # TODO: would be nice it this would be as the very first in code
    unless ($book_request->uid_is_allowed()) {
        # EXIT if he is to fast
        $self->render(
            message => 'ERROR: To many requests from: '
            . $self->tx->remote_address
            . "- Only one request per $book_request->{uid_expiration} "
            . "seconds allowed.",
            optional_message => '',
        );
        $log->warn( 'Perltuts: fast request from: '
                    . $self->tx->remote_address
                    . ' - 1 request allowed per '
                    . $book_request->{uid_expiration}
                    . ' seconds.'
                  );
    }

    # check if we have the book already in cache
    if ($book_request->is_cached()) {

        # get the book from cache
        my $book = $book_request->get_book();

        # send the book to the client
        return $self->send_download_to_client($book, $book_name);
    }
    else {

        $self->app->log->info("not in cache: '$name'");

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
                        title => $name,
                        author => "Perltuts",
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
        $book_request->cache_book($bin, $caching_seconds);

        # send the EBook to the client
        return $self->send_download_to_client($bin, $book_name);
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

1;
