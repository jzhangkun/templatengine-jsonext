#!/usr/bin/perl
# ut test for module - WMMIG::PGConfig
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../..";
use Test::More tests => 3;

# use ok
BEGIN { use_ok("WMMIG::PGConfig", qw{ %PGConf select_pgmodule select_pgpayload } ) }

subtest 'configuration' => sub {
    plan tests => 2;
    eval { $PGConf{5} = "SOMETHING" };
    like($@, qr{Modification of a read-only value attempted},
        '%PGConf is readonly, key is not allowed to change');
    
    eval { $PGConf{999} = "SOMETHING" };
    like($@, qr{Modification of a read-only value attempted},
        '%PGConf is readonly, key is not allowed to add');
};

subtest 'function' => sub {
    plan tests => 12;
    can_ok(__PACKAGE__, $_)
        for qw( select_pgmodule select_pgpayload);
    # select_pgmodule;
    my $pgm = select_pgmodule();
    is(ref($pgm), 'CODE',
        "select_pgmodule - return with coderef");
    is($pgm->(5), 'WMMIG::order_conf',
        "select_pgmodule - return the module name");
    is($pgm->(5), 'WMMIG::order_conf',
        "select_pgmodule - still return the module name");
    is($pgm->(999), undef,
        "select_pgmodule - data not found");
    is($pgm->(), undef,
        "select_pgmodule - data not found");
    
    # select_pgpayload
    my $pgp = select_pgpayload();
    is(ref($pgp), 'CODE',
        "select_pgpayload - return with coderef");
    is($pgp->(5), 'order-confirmation',
        "select_pgpayload - return the payload name");
    is($pgp->(5), 'order-confirmation',
        "select_pgpayload - still return the payload name");
    is($pgp->(999), undef,
        "select_pgpayload - data not found");
    is($pgp->(), undef,
        "select_pgpayload - data not found");
};
