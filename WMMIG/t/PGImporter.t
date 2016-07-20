#!/usr/bin/perl
# ut test for WMMIG::PGImproter
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../..";
use Test::More tests => 5;

# use ok
BEGIN { use_ok("WMMIG::PGImporter") }

subtest 'basic method' => sub {
    plan tests => 7;

    # basic method (5)
    my $o = new_ok("WMMIG::PGImporter");
    can_ok($o,$_) for qw(
        if_loaded
        get_method
        load_module
        load_method
    );

    # module attribute (2)
    ok( !$o->if_loaded(5),
        "nothing is loaded at the first beginning");
    ok( !$o->if_loaded(), 
        "id is not defined");
};

subtest 'load_method' => sub {
    plan tests => 4;
    my $o = WMMIG::PGImporter->new();
    my $package_order_conf =<<'PACKAGE';
package WMMIG::order_conf;
no warnings 'redefine';
sub genEmailPayload {
    return "order conf payload";
}

1;
PACKAGE
    eval "$package_order_conf";
    die if $@;
    my $method = $o->load_method("WMMIG::order_conf");

    is(ref($method),'CODE',
        "load the method");
    is($method->(), 'order conf payload',
        "executed the interface");

    $package_order_conf =<<'PACKAGE';
package WMMIG::ship_conf;
no warnings 'redefine';

1;
PACKAGE
    eval "$package_order_conf";
    die if $@;
    eval {
        $method = $o->load_method("WMMIG::ship_conf");
    };
    like($@, qr{\[WMMIG::ERROR\] WMMIG::ship_conf genEmailPayload not defined},
        "abort for undefined genEmailPayload");

    eval {
        $method = $o->load_method();
    };
    like($@, qr{\[WMMIG::ERROR\] module not defined},
        "abort for undefined module");
};

subtest 'load_module' => sub {
    plan tests => 3;
    my $o = WMMIG::PGImporter->new();
    SKIP: {
      eval "use WMMIG::order_conf";
      skip "WMMIG::order_conf not found", 1 if $@;
      is($o->load_module(5), "WMMIG::order_conf",
          "MIG module is loaded");
    };
    SKIP: {
      eval "use WMMIG::order_conf";
      skip "WMMIG::order_conf was found", 1 unless $@;
      eval { $o->load_module(5) };
      like($@, qr{\[WMMIG::ERROR\] WMMIG::order_conf loading fail},
          "abort for not finding the WMMIG::order_conf");
    }
    eval { $o->load_module(999) };
    like($@, qr{\[WMMIG::ERROR\] module not defined},
        "abort for undefined module");
};

subtest 'get_method - basic' => sub {
    plan tests => 5;
    my $o = WMMIG::PGImporter->new();
    ok(!$o->if_loaded(5),
        "module is NOT into cache");

    SKIP : {
      eval "use WMMIG::order_conf";
      skip "WMMIG::order_conf not found", 3 if $@;
      my $method = $o->get_method(5);
      ok( $o->if_loaded(5),
        "module is loaded into cache");
      is( ref($method), 'CODE',
        "method is bound into cache");
      my $o1 = WMMIG::PGImporter->new();
      ok( $o1->if_loaded(5),
        "module is shared between objects");
    }
    # failed to load
    eval { $o->get_method(9999) };
    like($@, qr{\[WMMIG::ERROR\] ID\[9999\] not support},
        "9999 is not supported");
};


