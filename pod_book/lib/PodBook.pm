package PodBook;

use strict;
use warnings;

use Mojo::Base 'Mojolicious';
use Mojo::Log;

our $VERSION = 0.16;

# This method will run once at server start
sub startup {
  my $self = shift;

  # set home directory
  $self->home->parse( $ENV{POD_BOOK_APP} );

  # Switch to installable "public" directory
  $self->static->paths( [ $self->home->rel_dir('public') ] );

  # Switch to installable "templates" directory
  $self->renderer->paths( [ $self->home->rel_dir('templates') ] );

  # read config
  $self->plugin( 'YamlConfig', {file => $self->home . '/config.yml'} );

  my $config = $self->config;
  if ( $config->{reverse_proxy} ) {
      $ENV{MOJO_REVERSE_PROXY} = 1;
  }

  # set log level
  $self->app->log(
      Mojo::Log->new(
          level => ( $config->{logging}->{level} || 'debug' ),
          path  => ( $config->{logging}->{path}->{general} || $self->home . '/perlybook.log' ),
      )
  );

  # set new passphrase
  $self->app->secret( $config->{secret} || 'secret' );

  # prepare file-caches
  $self->plugin(CHI => {
    # perlybook CPAN
    $config->{caching}->{name} => {
      driver     => 'File',
      namespace  => $config->{caching}->{name},
      root_dir   => $config->{tmp_dir},
    },
    # perlybook Perltuts
    $config->{caching}->{name_perltuts} => {
      driver     => 'File',
      namespace  => $config->{caching}->{name_perltuts},
      root_dir   => $config->{tmp_dir},
    }
  });

  # Routes
  my $r = $self->routes;

  # Normal route to controller
  $r->route('/')        ->to('cpan_search#form');
  $r->route('/about')   ->to('about#list');
  $r->route('/perltuts')->to('perltuts#list');
}

1;
