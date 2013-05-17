use Mojo::Base -strict;

use Test::More;
use Mojolicious::Commands;

# generate plack_app
require Mojolicious::Command::generate::plack_app;
my $app = Mojolicious::Command::generate::plack_app->new;

ok $app->description, 'has a description';
ok $app->usage,       'has usage information';

done_testing();
