package WMMIG::PGPayload;
# Extension JSON - XJSON Payload for Pangaea Email
# By Jack Zhang(jzha154)
# On 2015-03-20
use strict;
use Data::Dumper;
use Scalar::Util qw(weaken looks_like_number);
use Storable qw(dclone);
use Carp;
use JSON;
use Exporter;
our @ISA    = qw( Exporter );
our @EXPORT = qw(
    genPayload
);
our @EXPORT_OK = qw(
    parse_hash
    parse_array
    parse_var
    pretty_json
    trace
);

# Debug Level, Reset using $WMMIG::PGPayload::DEBUG
# Level 0: no debug
# Level 4: details in parse_array and parse_hash
# Level 5: details in parse_var
our $DEBUG = 0;

# Function : pretty_json
# - can be used in command line and reformat your json object
# Usage : perl -MWMMIG::PGPayload=pretty_json -e 'pretty_json' json_file
sub pretty_json {
    local $/;
    my $tmpl = do { local $/; <ARGV> };
    return unless $tmpl;
    my $json = JSON->new()->pretty(1);
    print $json->encode( $json->decode($tmpl) );
}

# Function : genPayload
# - the main entry for parsing and substituting payload template
# - which having the syntax of XJSON
#  InParam : genPayload($payload,$hash);
# - $payload is the HASHref having the json object
# - $hash    is the HASHref having the data
# OutParam : substituted payload
sub genPayload {
    my ($tmpl,$hash) = @_;
    $tmpl = dclone($tmpl); # make sure we won't break the data
    $hash = dclone($hash); # and keep the cleaness
    confess "PGPayload MUST be HashRef!" unless ref($tmpl) eq 'HASH';
    my $mig = { root => WMMIG::PGToken->new($hash,1),
                head => WMMIG::PGToken->new($hash,1), };
    return parse_hash($tmpl,$mig);
}

# Function : dp_parser
# - distrubute the template with the exact parser
sub dp_parser {
    my ($tmpl) = @_; 
    my %dispatcher = ( 
        'HASH'  => \&parse_hash, 
        'ARRAY' => \&parse_array,
        'VALUE' => \&parse_var,
    );
    my $tp = ref($tmpl) || 'VALUE';
    if (exists $dispatcher{$tp}) {
        return $dispatcher{$tp}->(@_);
    } else {
        # some other types that doesn't need parsing
        return $tmpl;
    }
}

# Function : parse_array
# - parse JSON - ARRAY
sub parse_array {
    my ($tmpl, $last) = @_;
    my $ra = [];

    _DEBUG(4,"Current Template - " . Dumper($tmpl));

    # local defination
    my $def = shift @$tmpl;
    if ( ref($def) eq 'HASH' and not(%$def) ) {
        ;   # null hash means inheriting directly
    } 
    elsif ( ref($def) eq 'HASH' ) {
        # compose the local defination
        my $mig = find_token($def);
        if ($mig) {
            # inherit from last node
            for my $token ( keys %$last ) {
                next if can_not_inherit($token);
                $mig->{$token} = $last->{$token} 
                    if not exists $mig->{$token};
            }
            # parse new and append
            for my $token ( sort_token($mig) ) {
                next if $mig->{$token}->is_parsed;
                parse_token($token,$last,$mig);
            }
            $last = $mig;
        } else {
            # not a migration area ?
            # push back to array
            unshift @$tmpl, $def;
            # remain $last an continue
        }
    } 
    else {
        # unidentified stuff
        # push back 
        unshift @$tmpl, $def;
    }
    
    _DEBUG(4,"Local MigParam - " . Dumper($last));

    for my $nd (@$tmpl) {
        my $mig = find_token($nd);
        # substantialize token
        if ($mig) {
            # inherit from last node
            for my $token ( keys %$last ) {
                next if can_not_inherit($token);
                $mig->{$token} = $last->{$token}
                    if not exists $mig->{$token};
            }
            # parse new and append
            for my $token ( sort_token($mig) ) {
                next if $mig->{$token}->is_parsed;
                parse_token($token,$last,$mig);
            }
            _DEBUG(4,"Parsed MigParam - ".Dumper($mig));
            # deal with directive - list
            if (exists $mig->{list}) {
                my $list = delete $mig->{list};
                push @$ra, @{ $list->value };
            }
            # deal with directive - loop
            elsif (exists $mig->{loop}) {
                my $loop = delete $mig->{loop};
                for (@{ $loop->value }) {
                    # clone mig data and tune head
                    my $sub = dclone($mig);
                    my $subtmpl = dclone($nd);
                    $sub->{head}->value($_);
                    push @$ra, dp_parser($subtmpl,$sub,$sub);
                }
            }
        } else {
        # dispatch others
            $mig = $last;
            push @$ra, dp_parser($nd,$mig,$mig);
        }
    }
    return $ra;
}

# Function : parse_hash
# - parse JSON - HASH
sub parse_hash {
    my ($tmpl, $last) = @_;

    _DEBUG(4,"Current Template - " . Dumper($tmpl));

    my $mig = find_token($tmpl);
    # parse token
    if ($mig) {
            for my $token ( keys %$last ) {
                next if can_not_inherit($token);
                $mig->{$token} = $last->{$token}
                    if not exists $mig->{$token};
            }
            for my $token ( sort_token($mig) ) {
                next if $mig->{$token}->is_parsed;
                parse_token($token,$last,$mig);
            }
    } else {
        $mig = $last;
    }

    _DEBUG(4,"Parsed MigParam - " . Dumper($mig));

    my $rh = {}; 
    # loop in hash via each
    if (exists $mig->{loop} and exists $mig->{each}) {
        my $loop = delete $mig->{loop};
        my $each = delete $mig->{each};
        while ( my($k,$v) = each %{$loop->value} ) {
            # clone the mig data/tmpl
            my $sub = dclone($mig);
            my $subtmpl = dclone($each->value);
            # tune head
            $sub->{head}->value($v);
            $rh->{$k} = dp_parser($subtmpl,$sub,$sub);
        }
    }
    # keep deal with the left template
    while ( my($k,$v) = each %$tmpl ) {
        $rh->{$k} = dp_parser($v,$mig,$mig);
    }
    return $rh;
}

# Function : parse_var
# - parse XJSON - customed variable
# Such as:
# 1. {{attr}}      - get attr from "head" branch
# 2. {{node.attr}} - get attr from "node" branch
# 3. $hash->{attr} - eval the variable
# 4. B{{attr}}     - turn to Boolean, true/false
# 5. N{{attr}}     - turn to null if it's not defined
sub parse_var {
    my ($tmpl,$last,$curr) = @_;

    return $tmpl unless $tmpl;
    
    _DEBUG(5, "parse_var - \$last ".Dumper($last));
    _DEBUG(5, "parse_var - \$curr ".Dumper($curr));
    _DEBUG(5, "parse_var - \$tmpl ".Dumper($tmpl));

    if ( $tmpl =~   m!^\s* 
                        ((?:B|N)?) # boolean/null
                        \{\{ 
                          (\w+)  # attribute
                        \}\}
                       \s*$!x ) {
    # Indirect variable
    # $1 : attribute
    # DON'T USE node IN THIS FORM
        my ($attr,$idct) = ($2,$1);
        my $head = ( exists $curr->{head} and $curr->{head}->{is_parsed} )
                 ? $curr->{head}->{value}
                 : ( exists $last->{head} and $last->{head}->{is_parsed} )
                 ? $last->{head}->{value}
                 : undef;
        return "" unless $head;
        #confess "head is not found" unless $head;
        if (!$idct) {
            return ( exists $head->{$attr} and defined $head->{$attr} ) 
                 ? $head->{$attr} 
                 : "" ;
        }
        elsif ($idct eq 'B') {
            return ( exists $head->{$attr} and $head->{$attr} )
                 ? JSON::true
                 : JSON::false ;
        }
        elsif ($idct eq 'N') {
            return ( exists $head->{$attr} and defined $head->{$attr} )
                 ? $head->{$attr}
                 : JSON::null ;
        }
    }
    elsif ($tmpl =~ m!^\s*
                        ((?:B|N)?) # boolean/null
                        \{\{
                          (\w+)  # head/node
                           [.]   
                          (\w+)  # attribute
                        \}\} 
                       \s*$!x ) {
        my ($name,$attr,$idct) = ($2,$3,$1);
        my $node = ( exists $curr->{$name} and $curr->{$name}->{is_parsed} )
                 ? $curr->{$name}->{value}
                 : ( exists $last->{$name} and $last->{$name}->{is_parsed} )
                 ? $last->{$name}->{value}
                 : undef;
        return "" unless $node;
        #confess "node is not found" unless $node;
        if (!$idct) {
            return ( exists $node->{$attr} and defined $node->{$attr} )
                 ? $node->{$attr}
                 : "" ;
        }
        elsif ($idct eq 'B') {
            return ( exists $node->{$attr} and $node->{$attr} )
                 ? JSON::true
                 : JSON::false ;
        }
        elsif ($idct eq 'N') {
            return ( exists $node->{$attr} and defined $node->{$attr} )
                 ? $node->{$attr}
                 : JSON::null ;
        }
    }
    elsif ($tmpl =~ m{^\$(?:hash|root)}) {
    # Traditional Varibale
        my $hash = ( exists $last->{root} and $last->{root}->{is_parsed} )
                 ? $last->{root}->{value}
                 : ( exists $curr->{root} and $curr->{root}->{is_parsed} )
                 ? $curr->{root}->{value}
                 : undef;
        return "" unless $hash;
        #confess "root is not found" unless $hash;
        my $node;
        eval {                                                                      
            $node = eval "$tmpl";
        };
        confess "eval failed: $@" if $@;
        return ( defined $node ) ? $node : "";
    }
    else {
    # Constant
        return $tmpl;
    }
}

# Parse the migration token
sub parse_token {
    my ($token,$last,$mig) = @_;
    my $migtoken = $mig->{$token};
    my $value = parse_var($migtoken->value,$last,$mig);
    if ($value eq '') {
        # set default null array for "list", "loop"
        $value = [] if $token eq 'loop' or  $token eq 'list';
        # set default null hash if it's loop in hash
        $value = {} if $token eq 'loop' and exists $mig->{each};
    }
    $migtoken->value($value);
    $migtoken->is_parsed(1);
    return $migtoken;
}

# Find the migration token
# __MIG__
# 1> root
# 2> head
# 3> node 
#    support more nodes, such as node1, node2 ...
# 4> list - dereference current node as a array list
# 5> loop - loop the node with current template
sub find_token {
    my $tmpl = shift;
    return unless ref($tmpl) eq 'HASH';
    my $mig;
    if (exists $tmpl->{__MIG__}) {
        $mig = delete $tmpl->{__MIG__};
        for ( keys %$mig) {
            my $value  = $mig->{$_};
            $mig->{$_} = WMMIG::PGToken->new($value);
        }  
    } else {
        for my $k (keys %$tmpl) {
            next if $k !~ m{^__MIG_(\w+)__$};
            my $value  = delete $tmpl->{$k};
            $mig->{$1} = WMMIG::PGToken->new($value);
        }
    }
    return $mig;
}

# sort the tokens with priority
# for later parsing
sub sort_token {
    my %pri = (
        root => 0,
        head => 1,
        node => 2,
        list => 3,
        loop => 3,
        each => 4,
    );

    my $mig = shift;
    my @tokens =  
        map { $_->[0] }
       sort { $a->[1] <=> $b->[1]
           or $a->[2] <=> $b->[2] }
        map { m{(node)(\d+)}
              ? [$_, $pri{$1}, $2]
              : [$_, $pri{$_}, 0 ]
            } keys %$mig ;
    return @tokens;
}

# only head/root/nodes can be inherited from last branch
sub can_not_inherit {
    return ( $_[0] ne 'head' )
        && ( $_[0] ne 'root' )
        && ( $_[0] !~ m{^node\d*$});
}

# display debug info
sub _DEBUG {
    my ($level,$msg) = @_;
    print "DEBUG($level): $msg\n" if $level <= $DEBUG;
}

sub trace {
    return $DEBUG unless @_;
    my $level = shift;
    $DEBUG = looks_like_number($level) ? $level : 0;
    return $DEBUG;
}

package WMMIG::PGToken;

sub new {
    my $instance = shift;
    my $class = ref($instance) || $instance;
    my $self  = { value => undef, is_parsed => 0 };
    bless $self, $class;
    if (@_) {
        my ($value,$status) = @_;
        $self->value($value);
        $self->is_parsed($status);
    }
    return $self;
}

sub value {
    my $self = shift;
    $self->{value} = shift if @_;
    return $self->{value};
}

sub is_parsed {
    my $self = shift;
    $self->{is_parsed} = (shift) ? 1 : 0 if @_;
    return $self->{is_parsed};
}


1;
