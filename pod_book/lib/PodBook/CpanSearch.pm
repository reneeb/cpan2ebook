package PodBook::CpanSearch;

# this is a controller
use Mojo::Base 'Mojolicious::Controller';

# the are the tools we need from CPAN
use Mojo::Headers;
use Mojo::UserAgent;
use Regexp::Common 'net';
use File::Temp 'tempfile';
use File::Slurp 'read_file';
use MetaCPAN::API;

use EPublisher;
use EPublisher::Source::Plugin::MetaCPAN;
use EPublisher::Target::Plugin::EPub;
use EPublisher::Target::Plugin::Mobi;

# and some local tools
use PodBook::Utils::Request;

our $VERSION = 0.1;

# This action will render a template
sub form {
    my $self = shift;


    # lets load some values from the config file
    my $config = $self->config;
    my $userblock_seconds      = $config->{userblock_seconds};
    my $cache_name             = $config->{caching}->{name};
    my $caching_seconds        = $config->{caching}->{seconds};
    my $tmp_dir                = $config->{tmp_dir};
    my $opt_msg                = $config->{optional_message}              || '<!-- -->';
    my $listsize               = $config->{autocompletion_size}           || 10;

    my $log = $self->app->log;

    # set size of autocompletion result list in the template (JavaScript)
    if ( $listsize =~ /\D/ or $listsize > 100 ) {
        $listsize = 10;
    }
    $self->stash( listsize => $listsize );

    # set the optional message no matter what happens!
    $self->stash( optional_message => $opt_msg );

    # if textfield is empty we just display the starting page
    unless ($self->param('in_text')) {

        #################################################
        # HERE THE STANDARD STARTING PAGE GETS RENDERED #
        #################################################

        # Some funny texts
        my @messages = (
            'The CPAN as your EBook.',
            'Cook your Book.',
            'Read POD everywhere.',
            'Read Perl-Module-Documentation secretly in your bed at night.',
            'POD: Pod On Demand.',
            'Plain Old Documentation in Plain Old EBook.',
        );

        # choose a funny text randomly
        my $message = @messages[ int rand scalar @messages ];

        # and pass it to the template
        $self->render( message => $message, optional_message => $opt_msg );

        # EXIT
        return;
    }
    # otherwise we continue by checking the input

    # check the type of button pressed
    my $type;
    if ($self->param('MOBI')) {
        $type = 'mobi';
    }
    elsif ($self->param('EPUB')) {
        $type = 'epub';
    }
    else {
        # EXIT if unknown
        $self->render( message => 'ERROR: Type of ebook unknown.' );
        $self->app->log->warn( 'Type of ebook unknown' );
        return;
    }

    # check if the module name in the text field is some what valid
    my ($module_name) = $self->param('in_text') =~ m/^([[:print:]]+)$/;

    if ( !$module_name ) {
        # EXIT if not matching
        $self->render( message => 'ERROR: invalid chars in module name.' );
        $self->app->log->info( 'invalid chars in module name: ' . $self->param( 'in_text' ) );
        return;
    }

    # check the remote IP... just to be sure!!! (like taint mode)
    my $remote_address;
    my $pattern = $RE{net}{IPv4};
    if ($self->tx->remote_address =~ m/^($pattern)$/) {
        $remote_address = $1;
        $log->debug( "Request IP: $remote_address" );
    }
    else {
        # EXIT if not matching...
        # TODO: IPv6 will probably be a problem here...
        $self->render( message => 'ERROR: Are you a HACKER??!!.' );
        $log->warn( "IP denied: $remote_address - is it IPv6?");
        return;
    }


    # INPUT SEEMS SAVE!!!
    # So we can go on and try to process this request

    # meta cpan has trouble to find dists with ".pm" in its name,
    # so remove it
    $module_name=~ s/\.pm\z//;

    # we need to know the most recent version of the module requested
    # therefore we will ask MetaCPAN
    my $ua = Mojo::UserAgent->new;

    # MetaCPAN-Autocompletion has trouble with :: so we replace it with
    # url-encoded spaces (%20)
    my $web_module_name = $module_name;
    $web_module_name =~ s/:/%20/g;

    # we use the autocomplete feature of metacpan to match the user input
    # to something valid. So the best match (the first -> size=1) is what
    # the user gets
    my $url = 'http://api.metacpan.org/v0/search/autocomplete?q='
              . $web_module_name
              . '&size=1';

    # do the request
    my $autocomplete = $ua->get($url)->res;

    # if there is no result, MetaCPAN seems to have big trouble
    unless ($autocomplete) {
        $self->render(
            message => "ERROR: Can't reach MetaCPAN"
        );
        $self->app->log->error( 'Cannot reach MetaCPAN' );

        # Exit
        return;
    }

    # if the answer is not json (e.g. html) it seems like our request was
    # bad or that they do server maintenace
    unless ($autocomplete->content->headers
            ->{headers}->{'content-type'}->[0]->[0] =~ /json/) {
        $self->render(
            message => "ERROR: MetaCPAN does not answer as expected."
        );
        $self->app->log->error( 'MetaCPANs response looks unexpected' );

        # Exit
        return;
    }

    # extract the data we need from the json result
    my $fields                = $autocomplete->json->{hits}->{hits}->[0]->{fields};
    my $complete_release_name = $fields->{release};
    my $distribution          = $fields->{distribution};

    # if this value is false, the module probably does not exist
    unless ( $complete_release_name) {
        $self->render(
            message => "ERROR: Module not found"
        );

        # Exit
        return;
    }

    # finaly we have everything we need to build a request object!
    my $book_request = PodBook::Utils::Request->new(
        $remote_address,
        "metacpan::$complete_release_name",
        $type,
        $userblock_seconds,
        $cache_name,
        $tmp_dir,
    );

    # we check if the user is using the page to fast
    # TODO: would be nice it this would be as the very first in code
    unless ($book_request->uid_is_allowed()) {
        # EXIT if he is to fast
        $self->render(
            message => "ERROR: To many requests from: $remote_address "
            . "- Only one request per $book_request->{uid_expiration} "
            . "seconds allowed."
        );
        $log->warn( "fast request from: $remote_address - 1 request allowed per $book_request->{uid_expiration} seconds.");

        return;
    }

    $log->info( "eBook requested: $distribution");

    # check if we have the book already in cache
    if ($book_request->is_cached()) {

        # get the book from cache
        my $book = $book_request->get_book();

        # send the book to the client
        $self->send_download_to_client($book,
            "$complete_release_name.$type"
        );
    }
    # if the book is not in cache we need to fetch the POD from MetaCPAN
    # and render it into an EBook. We use the EPublisher to do that
    else {
        my ($fh, $filename) = tempfile(DIR => $tmp_dir, SUFFIX => '.book');
        unlink $filename; # we don't need the file, just the name of it

        # build the config for EPublisher
        my %config = ( 
            config => {
                pod2cpan_webservice => {
                    source => {
                        type    => 'MetaCPAN',
                        module => $distribution
                    },
                    target => { 
                        output => $filename,
                        title  => $complete_release_name,
                        author => "Perl",
                        # this option is ignored by "type: epub"
                        htmcover => "<h3>Perl Module Documentation</h3><h1>$complete_release_name</h1>Source: <a href='https://metacpan.org/'>https://metacpan.org</a><br />Powered by: <a href='http://perl-services.de'>http://perl-services.de</a><br />"
                    }   
                }   
            },  
            debug  => sub {
                print "@_\n";
            },  
        );

        # still building the config (and loading the right modules)
        if ($type eq 'mobi') {
            $config{config}{pod2cpan_webservice}{target}{type} = 'Mobi';
        }
        elsif ($type eq 'epub') {
            $config{config}{pod2cpan_webservice}{target}{type} = 'EPub';
        }
        else {
            # EXIT
            $self->render( message => 'ERROR: unknown book-type' );
        }

        my $publisher = EPublisher->new(
            %config,
            debug => sub{ $self->debug_epublisher( @_ ) },
        );
        
        # This code here would be neccesary if we don't trust the
        # $module_version anymore... since it's a bit 'old' (not even a sec)

        #my $sub_get_release_from_metacpan_source = sub {
            #my $metacpan_source = shift;
            #$self->{metacpan_source_release_version} = 
                #$metacpan_source->{release_version};
        #};
        #$publisher->set_hook_source_ref(
            #$sub_get_release_from_metacpan_source
        #);

        # fetch from MetaCPAN and render
        $publisher->run( [ 'pod2cpan_webservice' ] );


        # TODO: EPublisher should give me the stuff as bin directly
        my $bin = read_file( $filename, { binmode => ':raw' } ) ;
        unlink $filename;
        $book_request->set_book($bin);

        # we finally have the EBook and cache it before delivering
        $book_request->cache_book($caching_seconds);

        # send the EBook to the client
        $self->send_download_to_client($bin,
            "$complete_release_name.$type"
        );
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

    my $headers = Mojo::Headers->new();
    $headers->add(
        'Content-Type',
        "application/x-download; name=$name"
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
