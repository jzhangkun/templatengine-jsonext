#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../..";
use Test::More tests => 4;

# use ok (1)
BEGIN { 
  use_ok("WMMIG::PGUtil", qw{ date_to_iso8601 debug_level })
}

# can ok (1)
can_ok("WMMIG::PGUtil", "date_to_iso8601", "debug_level");


subtest 'Function - date_to_iso8601' => sub {
    plan tests => 4;
    my $date;
    $date = '2015/06/11 19:53:56';
    is( date_to_iso8601($date), '2015-06-11T19:53:56-07:00',
        "date format - yyyy/mm/dd hh24:mi:ss");
    $date = '19 MAY 2015 18:24';
    is( date_to_iso8601($date), '2015-05-19T18:24:00-07:00',
        "date format - DD MON YYYY HH24:MI");
    $date = '2015-06-11 19:53:56';
    is( date_to_iso8601($date), undef,
        "date format not match");
    $date = '';
    is( date_to_iso8601($date), undef,
        "date is null");
};

subtest 'Function - debug_level' => sub {
    plan tests => 6;
    use WMCE::Function qw( $debug );

    ok( !debug_level(1),
        "undefined system debug level");
    
    $debug = 1;
    ok( !debug_level(),
        "undefined user debug level");
    ok( !debug_level(0),
        "user defined level 0");
    ok( debug_level(1),
        "user level = system level");

    $debug = 3;
    ok( debug_level(2),
        "user level < system level");
    ok( !debug_level(4),
        "user level > system level");

};
