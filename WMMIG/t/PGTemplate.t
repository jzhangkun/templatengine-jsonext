#!/usr/bin/perl
# ut for WMMIG::PGTemplate
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../..";
use Test::More tests => 8;

our $runlevel;
# use_ok
BEGIN { 
    $runlevel = $ENV{WM_RUN_LEVEL} || "DEV";
    if ($runlevel eq 'DEV') {
        $ENV{HOME} = "$Bin/PGTemplate";
    }
}
BEGIN { use_ok("WMMIG::PGTemplate", qw[ $EMAIL_PGPL_PATH list_payload get_mtime ]) }

# global environment
is($EMAIL_PGPL_PATH, "$ENV{HOME}/wm_mail/payload",
    "PAYLOAD PATH ENV");

# list payload
subtest 'list payload' => sub {
    plan tests => 4;
    my $all = list_payload();
    is(ref($all),'HASH',
        "data structure");
    ok(exists $all->{5} && $all->{5} eq 'order-confirmation',
        "  5 - order confirmation");
    ok(exists $all->{6} && $all->{6} eq 'ship-confirmation.6',
        "  6 - shipping confirmation");
    ok(exists $all->{142} && $all->{142} eq 'ready-for-pickup.142',
        "142 - ready for pickup");
};

######## Test Data of DEV #######
# under "./PGTemplate/wm_mail/payload"
# Data list:
# 1. email type id : 5
#       event type : order-confirmation
#     Introduction : exist with good json format
# 2. email type id : 6
#       event type : ship-confirmation
#     Introduction : not exist
# 3. email type id : 142
#       event type : ready-for-pickup.142
#     Introduction : exist with bad json format

subtest 'init attribute' => sub {
    plan tests => 11;
    # new ok (1)
    my $pgt = new_ok("WMMIG::PGTemplate" => [id => 5]);
    #print Dumper $pgt;

    # attribute (7)
    is($pgt->id, 5,
        "object - email type id");
    is($pgt->file, 'order-confirmation',
        "object - file name");
    is($pgt->path, "$EMAIL_PGPL_PATH/order-confirmation",
        "object - file path");
    is($pgt->mtime, 0,
        "object - modified time is null");
    is($pgt->template, '',
        "object - template content is null");
    is($pgt->format, '',
        "object - template format is null");
    is($pgt->error, '',
        "object - no error");
    
    # exception (3)
    # fail for not having id
    ok( ! WMMIG::PGTemplate->new(),
        "new the object - missing the id");
    # fail for id not configured
    ok( ! WMMIG::PGTemplate->new(id => '9999'),
        "new the object - id not exist");
    SKIP: {
        skip "can only test in dev env", 1 if $runlevel ne 'DEV';
        # fail for payload file not found
        ok( ! WMMIG::PGTemplate->new(id => 6),
        "new the object - payload not exists");
    }
};

subtest "load and parse existing template" => sub {
    plan tests => 7;
    my $pgt = WMMIG::PGTemplate->new(id => 5);
    $pgt->load_tmpl();
    is($pgt->error,'',
        "loaded template");
    is($pgt->format, 'JSON',
        "format is JSON");
    SKIP: {
        skip "can only test in dev env", 2 if $runlevel ne 'DEV';
        is($pgt->template, qq|{ "comment" : "Just for testing" }\n|,
        "content json");
        ok($pgt->mtime,
        "modified time is updated timely");
    };

    $pgt->parse_tmpl();
    is($pgt->error, '',
        "parse template");
    is($pgt->format, 'HASH',
        "foramt turns to HASH");
    SKIP: {
        skip "can only test in dev env", 1 if $runlevel ne 'DEV';
        is_deeply($pgt->template, { "comment" => "Just for testing" },
        "content hash");
    }
};

subtest "load template fail" => sub {
    plan tests => 4;
    my $pgt = WMMIG::PGTemplate->new(id => 5);
    $pgt->{PATH} = 'a/b/c';
    $pgt->load_tmpl();
    like($pgt->error, qr{open file error},
        "load template error - open file error");
    is($pgt->template, "",
        "tempalte is null");
    is($pgt->format, "",
        "format is undefined");
    is($pgt->mtime, 0,
        "mtime is still 0");
};

SKIP: {
skip "can only test in dev env", 2 if $runlevel ne 'DEV';

subtest "load and parse template - bad json" => sub {
    plan tests => 5;
    my $pgt = WMMIG::PGTemplate->new(id => 142);
    $pgt->load_tmpl();
    is($pgt->template, qq|{ "bad json" }\n|,
        "loaded template");
    is($pgt->format, "JSON",
        "format is JSON");
    $pgt->parse_tmpl();
    like($pgt->error, qr/^parse payload error/,
        "parse template error - bad json format");
    is($pgt->format, "JSON",
        "foramt is not changed");
    is($pgt->template, qq|{ "bad json" }\n|,
        "content is not changed");
};

subtest "check the modified payload template" => sub {
    plan tests => 7;
    my $pgt = WMMIG::PGTemplate->new(id => 5);
    ok($pgt->is_modified(),
        "before loading template");
    $pgt->load_tmpl();
    $pgt->parse_tmpl();
    ok(!$pgt->is_modified,
        "after loading template");

    # mock to rewind the modified time back to 1hour ago
    $pgt->{MTIME} = $pgt->mtime - 3600;
    ok($pgt->is_modified,
        "file was updated");

    # reload the file to keep the same prerequisites
    $pgt = WMMIG::PGTemplate->new(id => 5);
    $pgt->load_tmpl();
    $pgt->parse_tmpl();
    ok(!$pgt->is_modified,
        "file was reloaded");
    # mock to undef path
    $pgt->{PATH} = '';
    ok($pgt->is_modified,
        "path is missed");

    # reload the file to keep the same prerequisites
    $pgt = WMMIG::PGTemplate->new(id => 5);
    $pgt->load_tmpl();
    $pgt->parse_tmpl();
    ok(!$pgt->is_modified,
        "file was reloaded");
    # mock to a non-exist file path
    $pgt->{PATH} = 'a/b/c/d';
    ok($pgt->is_modified,
        "file not exist");
};

}
