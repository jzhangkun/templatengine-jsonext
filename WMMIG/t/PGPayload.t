#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/../..";
use Test::More tests => 11;
use JSON;

# Test use
BEGIN { use_ok("WMMIG::PGPayload") };

# Test function autoload
can_ok('WMMIG::PGPayload', qw{genPayload});

# Test package WMMIG::PGToken
subtest 'Package WMMIG::PGToken' => sub {
    plan tests => 9;
    my $token = new_ok("WMMIG::PGToken");
    is($token->value,undef,
        "Instance - initialize attr[value]");
    is($token->is_parsed,0,
        "Instance - initialize attr[is_parsed]");
    # value assignment
    $token->value("something");
    is($token->value,"something",
        "set value");
    # is_parsed assignment
    $token->is_parsed(1);
    ok($token->is_parsed,     # set to false
        "set is_parsed - 1");
    $token->is_parsed(0);
    ok(!$token->is_parsed,    # set to true
        "set is_parsed - 0");
    $token->is_parsed("a");
    ok($token->is_parsed,     # set to some string
        "set is_parsed - some string");
    $token->is_parsed("");
    ok(!$token->is_parsed,    # set to null string
        "set is_parsed - null string");
    $token->is_parsed(1);     # reset back to true
    $token->is_parsed(undef); # set to undef
    ok(!$token->is_parsed,
        "set is_parsed - undefined");
};

# Test private method
# find_token
# sort_token
# can_not_inherit
# parse_token
subtest "private method" => sub {
    plan tests => 29;
    for (qw( find_token
             sort_token
             parse_token
             can_not_inherit)) {
        no strict 'refs';
        *$_ = \&{"WMMIG::PGPayload::$_"};
    }
    
    # can_not_inherit
    # test case - total 7
    ok(!can_not_inherit('head'),
        "could inherit from head");
    ok(!can_not_inherit('root'),
        "could inherit from root");
    ok(!can_not_inherit('node'),
        "could inherit from node");
    ok(!can_not_inherit('node1'),
        "could inherit from node1");
    ok(can_not_inherit('loop'),
        "can not inherit from loop");
    ok(can_not_inherit('list'),
        "can not inherit from list");
    ok(can_not_inherit('each'),
        "can not inherit from each");  # USCBS-3463

    # sort_token
    # test case - total 1
    my $mig = { map { $_ => WMMIG::PGToken->new() } 
                qw(list node1 head each node loop root node2) };
    my @sorted = sort_token($mig);
    ok(("@sorted" eq "root head node node1 node2 list loop each" ||
        "@sorted" eq "root head node node1 node2 loop list each" ),
        "sort token with priority");   # USCBS-3463

    # find_token
    # test case - total 5
    # - non-hash
    ok(!defined(find_token([])),
        "no token if provided non-hash data");
    # - short format
    my ($tmpl);
    $tmpl = {
        "__MIG__" => {
            root => 'ROOT',
            head => 'HEAD',
        },
    };
    $mig = find_token($tmpl);
    is($mig->{root}->value, 'ROOT',
        "found root in short-formatted MIG");
    is($mig->{head}->value, 'HEAD',
        "found head in short-formatted MIG");
    $mig = '';
    # - long format
    $tmpl = {
        "__MIG_head__" => 'HEAD',
        "__MIG_root__" => 'ROOT',
    };
    $mig = find_token($tmpl);
    is($mig->{root}->value, 'ROOT',
        "found root in long-formatted MIG");
    is($mig->{head}->value, 'HEAD',
        "found head in long-formatted MIG");
    
    # parse_token
    my $hash = {
        fruits => [qw{ apple banana orange }],
    };
    my $last = {
        root => WMMIG::PGToken->new($hash,1),
        head => WMMIG::PGToken->new($hash,1),
    };
    my $node;

    # - head (4)
    # -- elements
    $mig = {
        head => WMMIG::PGToken->new('{{fruits}}'),
    };
    parse_token('head',$last,$mig);
    $node = $mig->{head};
    ok($node->is_parsed,
        "parsed token - head is parsed");
    is_deeply($node->value, [qw{ apple banana orange }],
        "parsed token - head has elements");

    # -- non-elements
    $mig = {
        head => WMMIG::PGToken->new('{{not_exist}}'),
    };
    parse_token('head',$last,$mig);
    $node = $mig->{head};
    ok($node->is_parsed,
        "parsed token - head is parsed");
    is($node->value, '',
        "parsed token - head is null string");

    # - list and loop (4)
    # -- elements
    $mig = {
        list => WMMIG::PGToken->new('{{fruits}}'),
        loop => WMMIG::PGToken->new('{{fruits}}'),
    };
    parse_token('list',$last,$mig);
    $node = $mig->{list};
    ok($node->is_parsed,
        "parsed token - list is parsed");
    is_deeply($node->value, [qw{ apple banana orange }],
        "parsed token - list elements match");

    parse_token('loop',$last,$mig);
    $node = $mig->{loop};
    ok($node->is_parsed,
        "parsed token - loop is parsed");
    is_deeply($node->value, [qw{ apple banana orange }],
        "parsed token - loop elements match");
    
    # - list and loop (4)
    # -- non-elements
    $mig = {
        list => WMMIG::PGToken->new('{{not_exist}}'),
        loop => WMMIG::PGToken->new('{{not_exist}}'),
    };

    parse_token('list',$last,$mig);
    $node = $mig->{list};
    ok($node->is_parsed,
        "parsed token - list is parsed");
    is_deeply($node->value, [],
        "parsed token - list is empty array");

    parse_token('loop',$last,$mig);
    $node = $mig->{loop};
    ok($node->is_parsed,
        "parsed token - loop is parsed");
    is_deeply($node->value, [],
        "parsed token - loop is empty array");
    
    # USCBS-3463
    # loop in the hash via each (4)
    $mig = {
        loop => WMMIG::PGToken->new('{{not_exist}}'),
        each => WMMIG::PGToken->new('{{not_exist}}'),
    };
    parse_token('loop',$last,$mig);
    $node = $mig->{loop};
    ok($node->is_parsed,
        "parsed token - loop is parsed");
    is_deeply($node->value,{},
        "parsed token - loop is emtpy hash");
    parse_token('each',$last,$mig);
    $node = $mig->{each};
    ok($node->is_parsed,
        "parsed token - each is parsed");
    is($node->value,"",
        "parsed token - each is null");
};

use WMMIG::PGPayload qw(parse_var parse_array parse_hash);

# Test parse_var
subtest 'parse_var' => sub {
    plan tests => 23;
    # Can (1)
    can_ok('WMMIG::PGPayload', 'parse_var');
    my $hash = {
        'first_name' => 'Jack',
        'is_single'  => 1,
        'is_null_str'=> '',
        'is_0'       => 0,
        'undefined'  => undef,
        'address' => {
            city => 'SH',
            state => 'SD',
            country => 'CHINA',
        },
    };
    my $mig = { root => WMMIG::PGToken->new($hash,1),
                head => WMMIG::PGToken->new($hash,1) };
    my $tmpl;

    # String (9)
    # - default semantic
    $tmpl = '{{first_name}}';
    is(parse_var($tmpl,$mig),'Jack',
        'Variable Default assignment');
    # - node sematic
    $tmpl = '{{head.first_name}}';
    is(parse_var($tmpl,$mig),'Jack',
        'Variable Node assignment');
    # - direct sematic
    $tmpl = '$hash->{first_name}';
    is(parse_var($tmpl,$mig),'Jack',
        'Variable Direct assignment');
    # - undefined
    $tmpl = '{{undefined}}';
    is(parse_var($tmpl,$mig),"",   # undef will be turned into ""
        'Variable Default - undefined');
    $tmpl = '{{head.undefined}}';
    is(parse_var($tmpl,$mig),"",
        'Variable Node    - undefined');
    $tmpl = '$hash->{undefined}';
    is(parse_var($tmpl,$mig),"",
        'Variable Direct  - undefined');
    # - not exist
    $tmpl = '{{middle_name}}';
    is(parse_var($tmpl,$mig),"",   # not existed will be turned into ""
        'Variable Default - value not exists');
    $tmpl = '{{head.middle_name}}';
    is(parse_var($tmpl,$mig),"",
        'Variable Node    - value not exists');
    $tmpl = '$hash->{middle_name}}';
    is(parse_var($tmpl,$mig),"",  
        'Variable Direct  - value not exists');

    # Bool (8)
    # - ture
    $tmpl = 'B{{is_single}}';
    is(parse_var($tmpl,$mig),JSON::true,
        'Variable Default - Boolean : true');
    $tmpl = 'B{{head.is_single}}';
    is(parse_var($tmpl,$mig),JSON::true,
        'Variable Node    - Boolean : true');
    # - false: undefined
    $tmpl = 'B{{undefined}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Default - Boolean : false - undefined');
    $tmpl = 'B{{head.undefined}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Node    - Boolean : false - undefined');
    # - false: null string
    $tmpl = 'B{{is_null_str}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Default - Boolean : false - null string');
    $tmpl = 'B{{head.is_null_str}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Node    - Boolean : false - null string');
    # - false: zero
    $tmpl = 'B{{is_0}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Default - Boolean : false - 0');
    $tmpl = 'B{{head.is_0}}';
    is(parse_var($tmpl,$mig),JSON::false,
        'Variable Node    - Boolean : false - 0');

    # Null (4)
    # - undefined
    $tmpl = 'N{{undefined}}';
    is(parse_var($tmpl,$mig),JSON::null,
        'Variable Default - null : undefined');
    $tmpl = 'N{{head.undefined}}';
    is(parse_var($tmpl,$mig),JSON::null,
        'Variable Node    - null : undefined');
    # - defined
    $tmpl = 'N{{first_name}}';
    is(parse_var($tmpl,$mig),'Jack',
        'Variable Default - null : defined');
    $tmpl = 'N{{head.first_name}}';
    is(parse_var($tmpl,$mig),'Jack',
        'Variable Node    - null : defined');

    # node (1)
    $mig->{node} = WMMIG::PGToken->new($hash->{address},1);
    $tmpl = '{{node.city}}';
    is(parse_var($tmpl,$mig),'SH',
        'Variable Node - node');

};
 
# Test parse_hash
subtest 'parse_hash' => sub {
    plan tests => 9;
    # can (1)
    can_ok('WMMIG::PGPayload', 'parse_hash');
    my $hash = {
        first_name => 'Jack',
        last_name  => 'Zhang',
        address => {
            city => 'SH',
            state => 'SD',
            country => 'CHINA',
        },
    };
    my $json = JSON->new();
    my $mig  = { root => WMMIG::PGToken->new($hash,1),
                 head => WMMIG::PGToken->new($hash,1) };
    my ($tmpl,$rh);

    # bash (2)
    $tmpl =<<'HASH';
{
  "__MIG_head__" : "$hash",
  "firstName" : "{{first_name}}",
  "lastName"  : "{{last_name}}"
}
HASH
    $tmpl = $json->decode($tmpl);
    $rh = parse_hash($tmpl,$mig);
    is($rh->{firstName},'Jack',
        "Hash - firstName");
    is($rh->{lastName}, 'Zhang',
        "Hash - lastName");
    
    # Level2 (4)
    $tmpl =<<'HASH2';
{
  "__MIG_head__" : "$hash",
  "address" : {
    "__MIG_head__" : "{{address}}",
    "city"    : "{{city}}",
    "state"   : "{{state}}",
    "country" : "{{country}}"
  }
}
HASH2
    $tmpl = $json->decode($tmpl);
    $rh = parse_hash($tmpl,$mig);
    ok(exists $rh->{address},
        "Hash - exist address");
    my $addr = $rh->{address};
    is($addr->{city}, 'SH',
        "Hash - city");
    is($addr->{state}, 'SD',
        "Hash - state");
    is($addr->{country}, 'CHINA',
        "Hash - country");

    # deep recurring in hash (1)
    my $val =
       $hash->{H}->{A}->{S}->{H}->{5} = "Suit Up!";
    $tmpl=<<'HASH5';
{
  "__MIG_head__" : "$hash",
  "L1" : {
    "__MIG_head__" : "{{H}}",
    "L2" : {
      "__MIG_head__" : "{{A}}",
      "L3" : {
        "__MIG_head__" : "{{S}}",
        "L4" : {
          "__MIG_head__" : "{{H}}",
          "L5" : "{{5}}"
        }
      }
    }
  }
}
HASH5
    $tmpl = $json->decode($tmpl);
    $rh = parse_hash($tmpl,$mig);
    #print Dumper $rh;
    is($rh->{L1}->{L2}->{L3}->{L4}->{L5}, 'Suit Up!',
        "Hash - deeply recurring");

    # broken node (1)
    $tmpl =<<'HASH5';
{
  "__MIG_head__" : "$hash",
  "L1" : {
    "__MIG_head__" : "{{H}}",
    "L2" : {
      "__MIG_head__" : "{{a}}",
      "L3" : {
        "__MIG_head__" : "{{S}}",
        "L4" : {
          "__MIG_head__" : "{{H}}",
          "L5" : "{{5}}"
        }
      }
    }
  }
}
HASH5
    $tmpl = $json->decode($tmpl);    
    $rh = parse_hash($tmpl,$mig);
    #print Dumper $rh; 
    is($rh->{L1}->{L2}->{L3}->{L4}->{L5}, "",
        "Hash - broken node in middle");

};

subtest 'loop in the hash via each' => sub {
    plan tests => 28;
    my $hash = {
        first_name => 'Jack',
        last_name  => 'Zhang',
    };
    my $json = JSON->new();
    my $mig  = { root => WMMIG::PGToken->new($hash,1),
                 head => WMMIG::PGToken->new($hash,1) };
    my ($tmpl,$rh);
    
    # USCBS-3463
    # Loop/Each (10)
    $hash->{sibling} = {
        "sister"  => {
            name => 'Taylor',
            age  => '16',
        },
        "brother" => {
            name => 'Jason',
            age  => '22',
        },
    };
    $hash->{total_kids} = '4';

    $tmpl =<<'HASHLOOP';
{
  "__MIG_head__" : "$hash",
  "Children" : {
    "__MIG_loop__" : "{{sibling}}",
    "__MIG_each__" : {
      "Name" : "{{name}}",
      "Age"  : "{{age}}"
    },
    "myself" : {
      "firstName" : "{{first_name}}",
      "lastName"  : "{{last_name}}"
    },
    "Total"  : "{{total_kids}}"
  }
}
HASHLOOP
    $tmpl = $json->decode($tmpl);
    $rh = parse_hash($tmpl,$mig);
    #print Dumper $rh;
    ok(exists $rh->{Children}->{sister}, 
        "Each hash - find my sister");
    ok(exists $rh->{Children}->{brother}, 
        "Each hash - find my brother");
    ok(exists $rh->{Children}->{myself}, 
        "Each hash - find myself");
    my $sis = $rh->{Children}->{sister};
    my $bro = $rh->{Children}->{brother};
    my $me  = $rh->{Children}->{myself};
    is($sis->{Name}, 'Taylor',
        "Each hash - sister name");
    is($sis->{Age}, '16',
        "Each hash - sister age");
    is($bro->{Name}, 'Jason',
        "Each hash - brother name");
    is($bro->{Age}, '22',
        "Each hash - brother age");
    is($me->{firstName}, 'Jack',
        "Each hash - find my first name");
    is($me->{lastName}, 'Zhang',
        "Each hash - find my last name");
    is($rh->{Children}->{Total}, '4',
        "Each hash - find total kids");

    # loop in the loop (18)
    $hash->{sibling} = {
        "sister"  => {
            name => "Taylor",
            age  => '16',
            habit => {
                'love' => { 
                    playing => 'HelloKitty',
                    doing   => 'Sleeping',
                },
                'dislike' => { 
                    playing => 'Pinao',
                    doing   => 'Running',
                } 
            },
        },
        "brother" => {
            name => 'Jason',
            age  => '22',
            habit => {
                'love' => { 
                    playing => 'Football',
                    doing   => 'Hiking',
                },
                'dislike' => { 
                    playing => 'Pingpang',
                    doing   => 'Lying',
                } 
            },
        },
    };

    $tmpl =<<'HASHLOOP2';
{
  "__MIG_head__" : "$hash",
  "Children" : {
    "__MIG_loop__" : "{{sibling}}",
    "__MIG_each__" : {
      "Name" : "{{name}}",
      "Age"  : "{{age}}",
      "__MIG_loop__" : "{{habit}}",
      "__MIG_each__" : {
          "toPlay" : "{{playing}}",
          "toDo"   : "{{doing}}"
      }
    },
    "myself" : {
      "firstName" : "{{first_name}}",
      "lastName"  : "{{last_name}}"
    },
    "Total"  : "{{total_kids}}"
  }
}
HASHLOOP2
    $tmpl = $json->decode($tmpl);
    #print Dumper $tmpl;
    #print Dumper $mig;
    #$WMMIG::PGPayload::DEBUG = 5;
    $rh = parse_hash($tmpl,$mig);
    #$WMMIG::PGPayload::DEBUG = 0;
    #print Dumper $rh;

    ok(exists $rh->{Children}->{sister}, 
        "Each hash - find my sister");
    ok(exists $rh->{Children}->{brother}, 
        "Each hash - find my brother");
    ok(exists $rh->{Children}->{myself}, 
        "Each hash - find myself");
    $sis = $rh->{Children}->{sister};
    $bro = $rh->{Children}->{brother};
    $me  = $rh->{Children}->{myself};
    is($sis->{Name}, 'Taylor',
        "Each hash - sister name");
    is($sis->{Age}, '16',
        "Each hash - sister age");
    is($sis->{love}->{toPlay}, "HelloKitty",
        "Each hash - sister love to play");
    is($sis->{love}->{toDo}, "Sleeping",
        "Each hash - sister love to do");
    is($sis->{dislike}->{toPlay}, "Pinao",
        "Each hash - sister dislikes to play");
    is($sis->{dislike}->{toDo}, "Running",
        "Each hash - sister dislikes to do");
    is($bro->{Name}, 'Jason',
        "Each hash - brother name");
    is($bro->{Age}, '22',
        "Each hash - brother age");
    is($bro->{love}->{toPlay}, "Football",
        "Each hash - brother love to play");
    is($bro->{love}->{toDo}, "Hiking",
        "Each hash - brother love to do");
    is($bro->{dislike}->{toPlay}, "Pingpang",
        "Each hash - brother dislikes to play");
    is($bro->{dislike}->{toDo}, "Lying",
        "Each hash - brother dislikes to do");
    is($me->{firstName}, 'Jack',
        "Each hash - find my first name");
    is($me->{lastName}, 'Zhang',
        "Each hash - find my last name");
    is($rh->{Children}->{Total}, '4',
        "Each hash - find total kids");

};

# Test parse_array
subtest 'parse_array' => sub {
    plan tests => 9;
    can_ok('WMMIG::PGPayload', 'parse_array');
    my $hash = {
        fruits => [qw( apple banana orange )],
        items  => [
            {
                name  => 'apple',
                price => '1',
                qty   => '5',
            },
            {
                name  => 'banana',
                price => '2',
                qty   => '6',
            },
            {
                name  => 'orange',
                price => '3',
                qty   => '7',
            },
        ],
    };   
    my $json = JSON->new();
    my $mig  = { root => WMMIG::PGToken->new($hash,1),
                 head => WMMIG::PGToken->new($hash,1) };
    my $tmpl;
    # list - normal
    $tmpl =<<'LIST';
[ 
  { "__MIG_root__" : "$hash",
    "__MIG_head__" : "$hash" },
  { "__MIG_list__" : "{{fruits}}" } 
]    
LIST
    $tmpl = $json->decode($tmpl);
    is_deeply(parse_array($tmpl,$mig),$hash->{fruits},
        "List items - full configuration in hash");
    # list - null hash as the 1st configuration
    $tmpl =<<'LIST';
[ 
  {},
  { "__MIG_list__" : "{{fruits}}" } 
]    
LIST
    $tmpl = $json->decode($tmpl);
    is_deeply(parse_array($tmpl,$mig),$hash->{fruits},
        "List items - null configuration in hash");
    # loop - normal
    $tmpl =<<'LOOP';
[
  { "__MIG_root__" : "$hash",
    "__MIG_head__" : "$hash" },
  {
    "__MIG_loop__" : "{{items}}",
    "Fruit" : "{{name}}",
    "Price" : "{{price}}",
    "Quantity" : "{{qty}}"
  }
]
LOOP
    $tmpl = $json->decode($tmpl);
    my $ra = parse_array($tmpl,$mig);
    is(scalar(@$ra),3,
        "Loop items - item count");
    is_deeply(shift(@$ra),{ Fruit => 'apple', Price => 1, Quantity => 5 },
        "Loop items - item 1");
    is_deeply(shift(@$ra),{ Fruit => 'banana', Price => 2, Quantity => 6 },
        "Loop items - item 2");
    is_deeply(shift(@$ra),{ Fruit => 'orange', Price => 3, Quantity => 7 },
        "Loop items - item 3");

    # unindentified stuff
    $tmpl = <<'UFO';
[
    "Alien"
]
UFO
    $tmpl = $json->decode($tmpl);
    is_deeply(parse_array($tmpl,$mig), ['Alien'],
        "UFO - Alien");
    $tmpl = <<'UFO';
[
    ["Aliens"]
]
UFO
    $tmpl = $json->decode($tmpl);
    is_deeply(parse_array($tmpl,$mig), [['Aliens']],
        "UFO - Aliens");

};

subtest 'have tokens in loop' => sub {
    plan tests => 9;
    my $hash = {
        sibling => [
            {
                name => 'Taylor',
                age  => '16',
                habit => {
                    love => 'HelloKitty',
                    dislike => 'Piano',
                },
            },
            {
                name => 'Jason',
                age  => '22',
                habit => {
                    love => 'Football',
                    dislike => 'PingPang',
                },
            },
        ],
    };

    my $json = JSON->new();
    my $mig  = { root => WMMIG::PGToken->new($hash,1),
                 head => WMMIG::PGToken->new($hash,1) };
    my $tmpl;

    $tmpl =<<'TokenInLoop';
[
  { "__MIG_root__" : "$hash",
    "__MIG_head__" : "$hash" },
  {
    "__MIG_loop__" : "{{sibling}}",
    "Name" : "{{name}}",
    "Age"  : "{{age}}",
    "Habit" : {
      "__MIG_head__" : "{{habit}}",
      "Love" : "{{love}}",
      "Dislike" : "{{dislike}}"
    }
  }
]
TokenInLoop

    $tmpl = $json->decode($tmpl);
    #print Dumper $tmpl;
    #print Dumper $mig;
    #$WMMIG::PGPayload::DEBUG = 5;
    my $ra = parse_array($tmpl,$mig);
    #$WMMIG::PGPayload::DEBUG = 0;
    #print Dumper $ra;

    is( scalar(@$ra), 2,
        "sibling num");
    my $sis = $ra->[0];
    my $bro = $ra->[1];
    is( $sis->{Name}, "Taylor",
        "Sister name");
    is( $sis->{Age}, "16",
        "Sister age");
    is( $sis->{Habit}->{Love}, "HelloKitty",
        "Sister loves");
    is( $sis->{Habit}->{Dislike}, "Piano",
        "Sister dislikes");

    is( $bro->{Name}, "Jason",
        "Brother name");
    is( $bro->{Age}, "22",
        "Brother age");
    is( $bro->{Habit}->{Love}, "Football",
        "Brother loves");
    is( $bro->{Habit}->{Dislike}, "PingPang",
        "Brother dislikes");

};

use WMMIG::PGPayload qw( trace );
subtest "trace" => sub {
    plan tests => 7;
    can_ok("WMMIG::PGPayload", qw{trace});
    # change trace
    is($WMMIG::PGPayload::DEBUG,0,
        "Default debug level - 0");
    trace(1);
    is($WMMIG::PGPayload::DEBUG,1,
        "trace level - 1");
    trace(0);
    is($WMMIG::PGPayload::DEBUG,0,
        "trace level tune back to 0");
    trace(1000);
    is($WMMIG::PGPayload::DEBUG,1000,
        "trace level too high, but ok");
    trace("5");
    is($WMMIG::PGPayload::DEBUG,5,
        "trace level is string number");
    trace("l1");
    is($WMMIG::PGPayload::DEBUG,0,
        "trace level is string, reset 0");
};

# Test payload template
subtest 'Payload Template' => sub {
    plan tests => 13;
    my ($tmpl,$hash,$mig);
    my $json = JSON->new();
    $hash = {
        first_name => 'Jack',
        last_name  => 'Zhang',
        fruits  => [
            {
                name  => 'Apple',
                price => '1',
                qty   => '5',
            },
            {
                name  => 'Banana',
                price => '2',
                qty   => '6',
            },
            {
                name  => 'Orange',
                price => '3',
                qty   => '7',
            },
        ],
        toys => [
            {
                name  => 'Big White',
                qty   => 1,
            },
            {
                name  => 'Small Yellow',
                qty   => 3,
            },
        ],
    };

    $tmpl =<<'TMPL';
{
  "__MIG__" : {
    "root"  : "$hash",
    "head"  : "$hash"
  },
  "customerInfo" : {
    "firstName"  : "{{first_name}}",
    "lastName"   : "{{last_name}}"
  },
  "Inventory" : [
      { "__MIG_head__" : "$hash" },
      {
        "__MIG_loop__" : "{{fruits}}",
        "Name"  : "{{name}}",
        "Count" : "{{qty}}",
        "Category" : "Fruits",
        "can_eat"  : true
      },
      {
        "__MIG_loop__" : "{{toys}}",
        "Name"  : "{{name}}",
        "Count" : "{{qty}}",
        "Category" : "Toys",
        "can_eat"  : false
      }
  ]
}
TMPL
    $tmpl = $json->decode($tmpl);
    use Storable qw(dclone);
    my $org_tmpl = dclone($tmpl);
    my $org_hash = dclone($hash);
    my $phash = genPayload($tmpl,$hash);   
    is_deeply($tmpl, $org_tmpl,
        "Payload - still the same template");
    is_deeply($hash, $org_hash,
        "Payload - still the same hash");
    my $custInfo = $phash->{customerInfo};
    my $inventory = $phash->{Inventory};
    is($custInfo->{firstName}, 'Jack',
        "Payload - first name");
    is($custInfo->{lastName}, 'Zhang',
        "Payload - last name");
    my @inventory = @{ $phash->{Inventory} };
    is(scalar(@inventory), 5,
        "Inventory - total count");
    my ($apple, 
        $banana,
        $orange,
        $bigW, 
        $smlY) = @inventory;
    is($apple->{Name}, 'Apple',
        "Fruit apple - name");
    is($apple->{Count}, 5,
        "Fruit apple - count");
    is($apple->{Category}, 'Fruits',
        "Fruit apple - category");
    is($apple->{can_eat}, JSON::true,
        "Fruit apple - can eat");

    is($smlY->{Name}, 'Small Yellow',
        "Toy Small Yellow - name");
    is($smlY->{Count}, 3,
        "Toy Small Yellow - count");
    is($smlY->{Category}, 'Toys',
        "Toy Small Yellow - category");
    is($smlY->{can_eat}, JSON::false,
        "Toy Small Yellow - can not eat");
};

1;
