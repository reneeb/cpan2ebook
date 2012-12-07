package PodBook::CpanSearch;

# this is a controller
use Mojo::Base 'Mojolicious::Controller';

# the are the tools we need from CPAN
use Mojo::Headers;
use Mojo::UserAgent;
use File::Temp 'tempfile';
use File::Slurp 'read_file';
use MetaCPAN::API;

use EPublisher;
use EPublisher::Source::Plugin::MetaCPAN;
use EPublisher::Target::Plugin::EPub;
use EPublisher::Target::Plugin::Mobi;

# and some local tools
use PodBook::Utils::Request;

# This action will render a template
sub form {
    my $self = shift;


    # lets load some values from the config file
    my $config = $self->config;
    my $userblock_seconds      = $config->{userblock_seconds};
    my $cache_name             = $config->{caching}->{name};
    my $caching_seconds        = $config->{caching}->{seconds};
    my $tmp_dir                = $config->{tmp_dir};
    my $opt_msg                = $config->{optional_message}
                                 || '<!-- -->';
    my $listsize               = $config->{autocompletion_size}
                                 || 10;

    my $log = $self->app->log;

    # set size of autocompletion result list in the template (JavaScript)
    if ( $listsize =~ /\D/ or $listsize > 100 ) {
        $listsize = 10;
    }
    $self->stash( listsize => $listsize );

    # set the optional message no matter what happens!
    $self->stash( optional_message => $opt_msg );

    # we need to know the version number in the template
    $self->stash( appversion => $PodBook::VERSION );

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
            #'write perlybook, say ˈpɜːlˈiːbʊk',
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
        $self->app->log->info( 'invalid chars in module name: '
                                . $self->param( 'in_text' ) );
        return;
    }

    # check if the complete release should be in the book
    my $merge_release = 0;
    if ($self->param('book_selection')) {
        ($merge_release) =
            $self->param('book_selection') =~ m/^([[:print:]]+)$/;
    }

    # INPUT SEEMS SAVE!!!
    # So we can go on and try to process this request

    # meta cpan has trouble to find dists with ".pm" in its name,
    # so remove it
    $module_name=~ s/\.pm\z//;

    # sadly we have to do some redundant work...
    # the EPublisher will later, again query MetaCPAN, but we need some info
    # now. So we do the work twice, now and later with EPublisher.
    my $mcpan = MetaCPAN::API->new();
    my $module_info;

    # the info we need (for file storage and caching)
    my $complete_release_name;
    my $distribution;

    # now we first search in the modules if there is something
    eval {
        $module_info = $mcpan->fetch("module/$module_name");

        $complete_release_name = $module_info->{release};
        $distribution          = $module_info->{distribution};
    }
    # if not we look in the releases
    or eval {
        $module_info = $mcpan->fetch("release/$module_name");

        $complete_release_name = $module_info->{name};
        $distribution          = $module_info->{distribution};
    }
    # if nothing matches we can't deliver anything!
    or do {
        $self->render( message =>
            "MetaCPAN is down or does not know a module/release with the given name: '$module_name' (case sensitive)."
        );
        $log->info( "MetaCPAN down or not found: '$module_name'");
        return;
    };

    # create book name for the download, we do it already here, because
    # we now have the info and it's messy to do it below in the code
    my $book_name;
    if ($merge_release) {
        $book_name = "Release_$complete_release_name.$type";
    }
    else {
        # $module_name may contain '::' which should become '-'
        my $file_module_name = $module_name;
        $file_module_name =~ s/:/-/g;
        $file_module_name =~ s/--/-/g;
        $book_name = "Module_$file_module_name.$type";
    }

    # finaly we have everything we need to build a request object!
    my $cache_prefix;
    if ($merge_release) {
        $cache_prefix = 'metacpan';
    }
    else {
        $cache_prefix = "metacpan::moduleonly::$module_name";
    }

    my $book_request = PodBook::Utils::Request->new(
        user_id               => $self->tx->remote_address,
        item_key              => $cache_prefix . '::'
                                               . $complete_release_name,
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
            . "seconds allowed."
        );
        $log->warn( 'fast request from: '
                    . $self->tx->remote_address
                    . ' - 1 request allowed per '
                    . $book_request->{uid_expiration}
                    . ' seconds.'
                  );

        return;
    }

    $log->info( 'Request from '
                . $self->tx->remote_address
                . ", looking up '$module_name', mapping to '$distribution' from '$complete_release_name'");

    # check if we have the book already in cache
    if ($book_request->is_cached()) {

        # get the book from cache
        my $book = $book_request->get_book();

        # send the book to the client
        $self->send_download_to_client($book, $book_name);
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
                        author => "CPAN",
                        # this option is ignored by "type: epub"
                        htmcover => "<h3>Perl Module Documentation</h3><h1>$complete_release_name</h1>Data source: <a href='https://metacpan.org/'>metacpan.org</a><br />Powered by: <a href='http://perl-services.de'>perl-services.de</a><br />Downloaded from: <a href='http://perlybook.org'>perlybook.org</a><br />"
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

        # Overwrite config if not the complete release is wanted
        unless ($merge_release eq 'distribution') {
            $config{config}{pod2cpan_webservice}{source}{onlythis} = 'true';
            $config{config}{pod2cpan_webservice}{source}{module}
                = $module_name;
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

        # we finally have the EBook and cache it before delivering
        $book_request->cache_book($bin, $caching_seconds);

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
