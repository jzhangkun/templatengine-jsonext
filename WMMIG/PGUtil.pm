package WMMIG::PGUtil;
use strict;
our @ISA = qw( Exporter );
use Time::Local qw(timelocal);
use POSIX qw(strftime);
use WMCE::Function qw( $debug );

our @EXPORT = qw(
);
our @EXPORT_OK = qw(
    date_to_iso8601
    debug_level
);

my @MONTHS = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %MONTHS;
@MONTHS{@MONTHS} = (0 .. 11);
@MONTHS{map uc(), @MONTHS} = (0 .. 11);

sub date_to_iso8601 {
    my $epoch;
    my ($day, $month, $year, $h, $m, $s);
    if ($_[0] =~ m{(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2}):(\d{2})}) {
        # Date format as 'yyyy/mm/dd hh24:mi:ss'
        ($year, $month, $day, $h, $m, $s) = ($1-1900, $2-1, $3, $4, $5, $6);
    }
    elsif ($_[0] =~ m/(\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})/) {
        # Date format as 'DD MON YYYY HH24:MI'
        ($day, $month, $year, $h, $m, $s) = ($1, $MONTHS{$2}, $3-1900, $4, $5, 0);
    }
    $epoch = eval { timelocal($s, $m, $h, $day, $month, $year) };
    return unless defined $epoch;
    (my $tz = strftime("%z", localtime($epoch))) =~ s/(\d\d)(\d\d)/$1:$2/;
    return strftime("%Y-%m-%dT%H:%M:%S", localtime($epoch)) . $tz;
}

# open the debug when the system level >= current level
sub debug_level {
    my $usr_level = shift || 0;
    return 0 if $usr_level == 0;
    my $sys_level = (defined $debug) ? $debug : 0;
    return $sys_level >= $usr_level;
}

1;
