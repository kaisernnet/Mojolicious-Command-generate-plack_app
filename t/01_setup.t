use Mojo::Base -strict;

use Test::More;
use Mojo::Util qw(class_to_file);

# generate plack_app
require Mojolicious::Command::generate::plack_app;
my $app = Mojolicious::Command::generate::plack_app->new;

my $class = 'MyMojoliciousApp';
my $name = class_to_file $class;

ok $app->run($class), 'can run';
ok -f "$name/script/$name.psgi", 'psgi file exists';
ok -f "$name/lib/$class.pm", 'application class file exists';
ok -f "$name/config/config.pl", 'config file exists';

done_testing;
