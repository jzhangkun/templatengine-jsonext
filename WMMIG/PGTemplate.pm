package WMMIG::PGTemplate;
use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use JSON;

## To Export Functions and Variables
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( $EMAIL_PGPL_PATH list_payload get_mtime );

our $EMAIL_PGPL_PATH = File::Spec->catdir($ENV{HOME},"wm_mail","payload");

use lib '..'; #! - remember to remove it in prod
use WMMIG::PGConfig qw( %PGConf select_pgpayload);
{
    my $pgp = select_pgpayload();
    sub _is_found  { return (defined $pgp->($_[0])?1:0) }
    sub _pgpayload { return $pgp->($_[0]) }
}

## Function : list_payload
##   -- get all the payload listed in WMMIG::PGConfig
## InParam  : null
## OutParam : HashRef containing 
##            key => email type id
##            val => payload file name
sub list_payload {
    return { map { $_ => _pgpayload($_) } keys %PGConf };
}

## Function : get_mtime
##   -- get the modified timestamp of the file
## InParam  : absolute file path
## OutParam : epoch time
sub get_mtime { (stat $_[0])[9] }


## OO Model
## instantiate payload template
## InParam  :
##   -- id   => email type id
##   -- file => payload file name
## To Instantiate successfully
##   1. id is must 
##   2. id has been defined in WMMIG::PGConfig
##   3. file is optional, defaultly it will try to find in WMMIG::PGConfig
##      if it was defined it will be used directly
##   4. the file path will be checked to see if it exists  
sub new {
    my $class = shift;
    my %args  = @_;
    my $self  = {};
    for my $attr ( qw( id file ) ) {
        $self->{uc $attr} = $args{$attr} || '';
    }
    return unless $self->{ID} and _is_found($self->{ID});
    $self->{FILE} = _pgpayload($self->{ID})
        unless $self->{FILE};

    bless $self, $class;
    return $self->_init();
}

sub _init {
    my $self = shift;
    my $path = File::Spec->catfile($EMAIL_PGPL_PATH,$self->{FILE});
    return unless -e $path; 
    
    $self->{PATH}     = $path; # absolute path                                      
    $self->{MTIME}    = 0;     # last modified time                                 
    $self->{FORMAT}   = '';    # template format: 
                               # - JSON, JSON text
                               # - HASH, decoded JSON
    $self->{TEMPLATE} = '';    # template content, depends on current format  
    $self->{ERROR}    = '';    # error message
    
    return $self;
}

## Attribute atuo-accessing
for my $field ( qw( id file path mtime format template error ) ) {
    my $slot = __PACKAGE__ . "::$field";
    no strict "refs";
    *$slot = sub { shift->{uc $field} };
}

sub load_tmpl {
    my $self = shift;
    my $path = $self->{PATH};
    open(my $fh, '<', $path) or do {
        $self->{ERROR} = "open file error - $path : $@";
        return;
    };

    $self->{TEMPLATE} = do{ local $/; <$fh> };
    close($fh);

    $self->{MTIME}    = get_mtime($path);
    $self->{FORMAT}   = 'JSON';
    $self->{ERROR}    = '';
    return $self;
}

sub parse_tmpl {
    my $self = shift;
    my $json = JSON->new();

    my $parsed_tmpl;
    eval {
        $parsed_tmpl = $json->decode($self->{TEMPLATE});
    };
    if ($@) {
        $self->{ERROR} = "parse payload error: $@";
        return;
    }
    $self->{TEMPLATE} = $parsed_tmpl;
    $self->{FORMAT}   = 'HASH';
    $self->{ERROR}    = '';
    return $self;
}

## Function : is_modified
## -- check if the template has been modified or not
sub is_modified {
    my $self = shift;
    my $path = $self->path;
    return 1 unless $path and -e $path;  # always return yes if the template is gone
    return ($self->mtime < get_mtime($path)) ? 1 : 0 ;
}

1;
