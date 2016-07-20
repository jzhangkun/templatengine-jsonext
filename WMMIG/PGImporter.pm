package WMMIG::PGImporter;
use strict;
use warnings;
use Data::Dumper;
use Readonly;

# The common interface name for composing payload
Readonly::Scalar our $INTERFACE => "genEmailPayload";
Readonly::Scalar our $ERROR_TAG => "[WMMIG::ERROR]";

# The utility for pgmodule
use WMMIG::PGConfig qw( select_pgmodule );
{
    my $pgm = select_pgmodule();
    sub _is_found { return (defined $pgm->($_[0])?1:0) }
    sub _pgmodule { return $pgm->($_[0]) }
}

# Shared by different objects
# Index by Id
# Storing the reference to the module method
my %Cache = ();

sub new {
    my $class = shift;
    return bless \%Cache, $class;
}

sub get_method {
    my $self = shift;
    my $id   = shift;
    die  "$ERROR_TAG ID[$id] not support" if not _is_found($id);
    if (not $self->if_loaded($id)) {
        my $module  = $self->load_module($id);
        $Cache{$id} = $self->load_method($module); 
    }
    return $Cache{$id};
}

sub load_module {
    my $self = shift;
    my $id   = shift;
    my $module = _pgmodule($id);
    die  "$ERROR_TAG module not defined" unless defined $module;
    eval "use $module";
    die  "$ERROR_TAG $module loading fail: $@" if $@;
    return $module;
}

sub load_method {
    my $self = shift;
    my $module = shift;
    die  "$ERROR_TAG module not defined" unless defined $module;
    die  "$ERROR_TAG $module $INTERFACE not defined"
         unless $module->can($INTERFACE);
    no strict 'refs';
    my $subref = \&{"${module}::${INTERFACE}"};
    return $subref;
}

sub if_loaded {
    my $self = shift;
    my $id   = shift;
    return 0 if not defined $id;
    return 0 if not _is_found($id);
    return (exists $Cache{$id}) ? 1 : 0 ;
}

1;
