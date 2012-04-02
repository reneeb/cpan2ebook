package PodBook::CpanSearch;
use Mojo::Base 'Mojolicious::Controller';
use Regexp::Common 'net';

# This action will render a template
sub form {
    my $self = shift;

    # if textfield is empty we just display the starting page
    unless ($self->param('in_text')) {
        # EXIT
        $self->render( message => 'Please make your choice.' );
        return;
    }
    
    # otherwise we continue by checnking the input

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
        return;
    }

    # check if the module name in the text field is some what valid
    my $module_name;
    #TODO: No idea about the module name specs!!!
    if ($self->param('in_text') =~ m/^([\d\w\-]{3,100})$/) {
        $module_name = $1;
    }
    else {
        # EXIT if not matching
        $self->render( message => 'ERROR: Module name not accepted.' );
        return;
    }

    # check the remote IP... just to be sure!!! (like taint mode)
    my $remote_address;
    my $pattern = $RE{net}{IPv4};
    if ($self->tx->remote_address =~ m/^($pattern)$/) {
        $remote_address = $1;
    }
    else {
        # EXIT if not matching...
        # TODO: IPv6 will probably be a problem here...
        $self->render( message => 'ERROR: Are you a HACKER??!!.' );
        return;
    }


    # INPUT SEEMS SAVE!!!
    # So we can go on and try to process this request

    # lets load some values from the config file
    use YAML::Tiny;
    my $config = YAML::Tiny->new;
    $config = YAML::Tiny->read( 'config.yml' );
    my $userblock_seconds = $config->[0]->{userblock_seconds};

    # we need to know the most recent version of the module requested
    # therefore we will ask MetaCPAN
    use LWP::UserAgent;
    use HTTP::Response;
    use JSON;

    # we prepare the JSON POST
    my $uri = 'http://api.metacpan.org/v0/release/_search';
    my $json = '{"query" : { "terms" : { "release.distribution" : [ "'.$module_name.'" ] } }, "filter" : { "term" : { "release.status" : "latest" } }, "fields" : [ "distribution", "version" ], "size"   : 1}';
    my $req = HTTP::Request->new( 'POST', $uri );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( $json );

    # we ask MetaCPAN
    my $ua = LWP::UserAgent->new;
    my $response = $ua->request($req);

    # we fill the result into this variable
    my $module_version;
    if ($response->is_success) {
        my $res_json = $response->decoded_content;
        my $d  = decode_json $res_json;

        $module_version = $d->{hits}->{hits}->[0]->{fields}->{version};
        #print $d->{hits}->{hits}->[0]->{fields}->{distribution}";
        
        unless ($module_version) {
            # EXIT if there is no version...
            # this seems to mean, that the module does not exist
            $self->render(
                message => "ERROR: Module not found"
                );
            return;
        }

    }
    else {
        # EXIT if we can't reach MetaCPAN
        $self->render(
            message => "ERROR: Cant reach MetaCPAN - $response->status_line"
            );
        return;
    }

    # finally we have everything we need to build a request object!
    use PodBook::Utils::Request;
    my $book_request = PodBook::Utils::Request->new(
                                $remote_address,
                                "metacpan::$module_name-$module_version",
                                $type,
                                $userblock_seconds,
                                'pod2cpan_webservice',
                       );

    # we check if the user is using the page to fast
    # TODO: would be nice it this would as the very first in code
    unless ($book_request->uid_is_allowed()) {
        # EXIT if he is to fast
        $self->render(
            message => "ERROR: To many requests from: $remote_address "
            . "- Only one request per $book_request->{uid_expiration} "
            . "seconds allowed."
            );
        return;
    }


    # check if we have the book already in cache
    if ($book_request->is_cached()) {

        # get the book from cache
        my $book = $book_request->get_book();

        # send the book to the client
        $self->send_download_to_client($book,
                                       "$module_name-$module_version.$type"
                                      );
    }
    # if the book is not in cache we need to fetch the POD from MetaCPAN
    # and render it into an EBook. We use the EPublisher to do that
    else {
        use EPublisher;
        use EPublisher::Source::Plugin::MetaCPAN;

        use File::Temp 'tempfile';
        my ($fh, $filename) = tempfile(DIR => 'public/', SUFFIX => '.book');
        unlink $filename;

        # build the config for EPublisher
        my %config = ( 
            config => {
                pod2cpan_webservice => {
                    source => {
                        type    => 'MetaCPAN',
                        module => $module_name},
                    target => { 
                        output => $filename,
                        title  => "$module_name-$module_version",
                        author => "Perl",
                        # this option is ignored by "type: epub"
                        htmcover => "<h3>Perl Module Documentation</h3><h1>$module_name</h1>Module version: $module_version<br />Source: <a href='https://metacpan.org/'>https://metacpan.org/</a><br />Powered by: perl-services.de<br />"
                    }   
                }   
            },  
            debug  => sub {
                print "@_\n";
            },  
        );

        # still building the config (and loading the right modules)
        if ($type eq 'mobi') {
            use EPublisher::Target::Plugin::Mobi;
            $config{config}{pod2cpan_webservice}{target}{type} = 'Mobi';
        }
        elsif ($type eq 'epub') {
            use EPublisher::Target::Plugin::EPub;
            $config{config}{pod2cpan_webservice}{target}{type} = 'EPub';
        }
        else {
            # EXIT
            $self->render( message => 'ERROR: unknown book-type' );
        }

        my $publisher = EPublisher->new( %config );
        
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
        use File::Slurp;
        my $bin = read_file( $filename, { binmode => ':raw' } ) ;
        unlink $filename;
        $book_request->set_book($bin);

        # we finally have the EBook and cache it before delivering
        my $caching_seconds = $config->[0]->{caching_seconds};
        $book_request->cache_book($caching_seconds);

        # send the EBook to the client
        $self->send_download_to_client($bin,
                                       "$module_name-$module_version.$type"
                                      );
    }

    # if we reach here... something is wrong!
    $self->render( message => 'Book cannot be delivered :-)' );
}

sub send_download_to_client {
    my ($self, $data, $name) = @_;

    use Mojo::Headers;
    my $headers = Mojo::Headers->new();
    $headers->add('Content-Type',
                  "application/x-download; name=$name");
    $headers->add('Content-Disposition',
                  "attachment; filename=$name");
    $headers->add('Content-Description','ebook');
    $self->res->content->headers($headers);

    $self->render_data($data);
}

1;
