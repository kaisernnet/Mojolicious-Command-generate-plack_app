requires 'perl', '5.008001';

requires 'Mojolicious', '>= 4.0';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

