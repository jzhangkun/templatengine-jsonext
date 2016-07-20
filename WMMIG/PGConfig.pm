package WMMIG::PGConfig;
use strict;
use warnings;
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw( %PGConf select_pgmodule select_pgpayload );
use Readonly;

Readonly::Hash our %PGConf => (
    #id       pgmodule          pgpayload
    5   => [qw[ WMMIG::order_conf order-confirmation ]],
    6   => [qw[ WMMIG::ship_conf    ship-confirmation.6   ]],
    709 => [qw[ WMMIG::mp_ship_conf ship-confirmation.709 ]],
    142 => [qw[ WMMIG::in_store_delv_ready ready-for-pickup.142 ]],
	684 => [qw[ WMMIG::cust_cancel_success cancellation-confirmation.684 ]],
);

sub select_pgmodule {
    my $idx = 0;
    return sub {
        my $type_id = shift;
        return unless (defined $type_id) and (exists $PGConf{$type_id});
        return $PGConf{$type_id}[$idx];
    };
}

sub select_pgpayload {
    my $idx = 1;
    return sub {
        my $type_id = shift;
        return unless (defined $type_id) and (exists $PGConf{$type_id});
        return $PGConf{$type_id}[$idx];
    };
}


1;
