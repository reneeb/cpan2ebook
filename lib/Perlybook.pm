package Perlybook;

use v5.22;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Lite';

use Perlybook::Book;

our $VERSION = 0.28;

app->plugin('JSONConfig');
app->plugin('CHI');

app->config->{__VERSION__} = $VERSION;

my $config = app->config;
if ( $config->{reverse_proxy} ) {
    $ENV{MOJO_REVERSE_PROXY} = 1;
}

app->plugin( 'Mail' => $config->{mail} );

# set new passphrase
app->secrets( $config->{secrets} || ['aldsjalsdjqeojfsldfavjadnvskdaleioqsdklajavnmydwjhakdfsdklfvjjasdkfjjaksdjkhsdkflaskdvnskdjkfasdfjlasdjf' );

get '/about'; 

get '/' => sub {
    my $c = $_[0];

    if ( $c->param('source') ) {
        return Perlybook::Book::create( @_ );
    }

    my $messages = $c->config->messages || [ 'All your documentation belong to us' ];
    my $message  = $messages->[ int rand scalar $messages->@* ];

    $c->render('form');
};

post '/' => \&Perlybook::Book::create;


1;
