package Mojolicious::Command::generate::plack_app;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw(class_to_file class_to_path);
our $VERSION = '0.01';

sub run {
    my ($self, $class) = @_;
    $class ||= 'MyMojoliciousApp';

    # Prevent bad applications
    die <<EOF unless $class =~ /^[A-Z](?:\w|::)+$/;
Your application name has to be a well formed (camel case) Perl module name
like "MyApp".
EOF

    # Script
    my $name = class_to_file $class;
    $self->render_to_rel_file('plack', "$name/script/$name.psgi", $class);
    $self->render_to_rel_file('start', "$name/script/start.sh", $name);
    $self->chmod_file("$name/script/$name.psgi", 0744);
    $self->chmod_file("$name/script/start.sh", 0744);

    # Application class
    my $app = class_to_path $class;
    $self->render_to_rel_file('appclass', "$name/lib/$app", $class);

    # Controller
    my $controller = "${class}::Controller::Example";
    my $path       = class_to_path $controller;
    $self->render_to_rel_file('controller', "$name/lib/$path", $controller);

    # Test
    $self->render_to_rel_file('test', "$name/t/basic.t", $class);

    # Log directory
    $self->create_rel_dir("$name/log");

    # Static file
    $self->render_to_rel_file('static', "$name/public/index.html");
    $self->render_to_rel_file('scss', "$name/public/css/application.scss");
    $self->create_rel_dir("$name/public/images");
    $self->create_rel_dir("$name/public/js");
    $self->create_rel_dir("$name/public/fonts");


    # Templates
    $self->render_to_rel_file('import',
        "$name/templates/imports/header.html.ep");
    $self->render_to_rel_file('layout',
        "$name/templates/layouts/default.html.ep");
    $self->render_to_rel_file('welcome',
        "$name/templates/example/welcome.html.ep");

    # Config
    for my $config (qw(config deployment development)) {
        $self->render_to_rel_file('config', "$name/config/$config.pl");
    }

    # Some files and directories
    $self->render_to_rel_file('cpanfile', "$name/cpanfile");

    $self->create_rel_dir("$name/sandbox");
    $self->create_rel_dir("$name/tmp");
    $self->chmod_file("$name/tmp", 0777);
}

1;
__DATA__

@@ plack
% my $class = shift;
#!/usr/bin/env perl
use strict;
use warnings;

use Mojo::Server::PSGI;
use Plack::Builder;

use Data::MessagePack;
use <%= $class %>;

my $mp     = Data::MessagePack->new;
my $server = Mojo::Server::PSGI->new( app => <%= $class %>->new );

builder {
    enable 'Session';
    enable "File::Sass", syntax => "scss";
    enable "Static",
        path => qr!^/(?:(?:css|images|js)/|favicon\.ico$)!,
        root => './public';
    $server->to_psgi_app;
};

@@ start
% my $name = shift;
#!/bin/bash

case $1 in
    debug)
        carton exec -Ilib -- plackup -p 8080 \\
        -E development -R lib,templates script/<%= $name %>.psgi
        ;;
    start)
        carton exec -Ilib -- starman -p 8080 \\
        -E deployment --workers 5 -MMojolicious \\
        script/<%= $name %>.psgi
        ;;
    *)
        echo "Usage: $0 start|stop|debug"
        ;;
esac

@@ appclass
% my $class = shift;
package <%= $class %>;
use Mojo::Base 'Mojolicious';

use Plack::Session;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Config
    for my $file ('config', $self->mode) {
        $self->plugin('Config', {file => 'config/' . $file . '.pl'});
    }
    $self->secret($self->config->{APP_SECRET});

    $self->helper(psession => sub {
        Plack::Session->new($_[0]->req->env);
    });

    # Router
    my $r = $self->routes;

    # Routes
    $r->namespaces(['<%= $class %>::Controller']);
    $r->get('/')->to('example#welcome');
}

sub development_mode {
    my $self = shift;
    $self->logfile;
}

sub deployment_mode {
    my $self = shift;
    $self->logfile;
}

sub logfile {
    my $self = shift;

    my $log_name = $self->mode . '.log';
    $self->log->path( $self->home->rel_file( "log/$log_name" ) )
        if -w $self->home->rel_file('log');
}

1;

@@ controller
% my $class = shift;
package <%= $class %>;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template
sub welcome {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(
    message => 'Welcome to the Mojolicious real-time web framework!');
}

1;

@@ static
<!DOCTYPE html>
<html>
  <head>
    <title>Welcome to the Mojolicious real-time web framework!</title>
  </head>
  <body>
    <h2>Welcome to the Mojolicious real-time web framework!</h2>
    This is the static document "public/index.html",
    <a href="/">click here</a> to get back to the start.
  </body>
</html>

@@ scss

@charset "UTF-8";

body {
  background: #fff;
  color: #333;
  font-family: sans-serif;
  font-size: 100%;
}

@@ test
% my $class = shift;
use Mojo::Base -strict;

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('<%= $class %>');
$t->get_ok('/')->status_is(200)->content_like(qr/Mojolicious/i);

done_testing();

@@ import
  <header><h1><%%= title %></h1></header>

@@ layout
<!DOCTYPE html>
<html>
<head>
    <title><%%= title %></title>
    <meta charset="utf-8" />
    <%%= stylesheet '/css/application.css' %>
</head>
<%%= content %>
</html>

@@ welcome
%% layout 'default';
%% title 'Welcome';
<body>
<%%= include 'imports/header' %>
  <h2><%%= $message %></h2>
  This page was generated from the template "templates/example/welcome.html.ep"
  and the layout "templates/layouts/default.html.ep",
  <a href="<%%== url_for %>">click here</a> to reload the page or
  <a href="/index.html">here</a> to move forward to a static page.
</body>

@@ config
+{}

@@ cpanfile
requires 'Mojolicious', '>= 4.0';
requires 'EV';
requires 'IO::Socket::IP';
requires 'IO::Socket::SSL';

# Plack - Core and Essential Tools
requires 'PSGI';
requires 'Plack';
requires 'Starman';
requires 'Starlet';

# Plack - Recommended middleware components
requires 'Plack::Middleware::Session';
requires 'Plack::Middleware::Debug';
requires 'Plack::App::Proxy';
requires 'Plack::Middleware::ReverseProxy';

# Plack - Extra Middleware Components
requires 'Plack::Middleware::Status';
requires 'Plack::Middleware::File::Sass';

requires 'Data::MessagePack';
requires 'Encode';

__END__

=encoding utf-8

=head1 NAME

Mojolicious::Command::generate::plack_app - Plack App generator command

=head1 SYNOPSIS

    use Mojolicious::Command::generate::plack_app;

    my $app = Mojolicious::Command::generate::plack->new;
    $app->run(@ARGV);

=head1 DESCRIPTION

Mojolicious::Command::generate::plack_app is ...

=head1 LICENSE

Copyright (C) kaisernnet.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

kaisernnet E<lt>kaisernnet@gmail.comE<gt>

=cut

