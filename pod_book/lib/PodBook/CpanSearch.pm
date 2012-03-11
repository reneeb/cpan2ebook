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
    if ($self->param('in_text') =~ m/([\d\w:-]{3,100})/) {
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
    use PodBook::Utils::Request;
    my $book_request = PodBook::Utils::Request->new(
                                $remote_address,
                                "metacpan::$module_name",
                                $type,
                                'pod2cpan_webservice',
                       );

    # we check if the user is using the page to fast
    unless ($book_request->uid_is_allowed()) {
        # EXIT if he is to fast
        $self->render(
            message => "ERROR: To many requests from: $remote_address"
            );
        return;
    }

    # check if we have the book alread in cache
    if ($book_request->is_cached()) {
        # return the book from cache
    }
    else {
        # fetch from CPAN and create a Book
        # using EPublisher!
    }

    $self->render( message => 'Book cannot be delivered :-)' );
}

1;
