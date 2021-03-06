# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 

package App::Dochazka::REST::Util::Timestamp;

use 5.012;
use strict;
use warnings FATAL => 'all';
use DBI;
use Time::Piece;
use Time::Seconds;




=head1 NAME

App::Dochazka::REST::Util::Timestamp - date/time-related utilities 




=head1 VERSION

Version 0.352

=cut

our $VERSION = '0.352';




=head1 SYNOPSIS

Date/time-related utilities

    use App::Dochazka::REST::Util::Timestamp;

    ...


=head1 EXPORTS

This module provides the following exports:

=over 

=item C<$today> (string), e.g. '2014-07-09'

=item C<$today_ts> (string), e.g. '2014-07-09 00:00:00'

=item C<$yesterday> (string), e.g. '2014-07-08'

=item C<$yesterday_ts> (string), e.g. '2014-07-08 00:00:00'

=item C<$tomorrow> (string), e.g. '2014-07-10'

=item C<$tomorrow_ts> (string), e.g. '2014-07-10 00:00:00'

=item L<split_tsrange> (function)

=item L<canonicalize_ts> (function)

=item L<subtract_days> (function)

=item L<tsrange_equal> (function)

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( $today $today_ts $yesterday $yesterday_ts $tomorrow
    $tomorrow_ts canonicalize_ts subtract_days tsrange_equal );

our $t = localtime;
our $today = $t->ymd;
our $today_ts = $today . ' 00:00:00';
our $yesterday = ($t - ONE_DAY)->ymd;
our $yesterday_ts = $yesterday . ' 00:00:00';
our $tomorrow = ($t + ONE_DAY)->ymd;
our $tomorrow_ts = $tomorrow . ' 00:00:00';



=head1 FUNCTIONS


=head2 split_tsrange

Given a string that might be a tsrange, split it into its lower and upper
bounds (i.e. into two timestamps) by running it through the SQL statement:

    SELECT lower(CAST( ? AS tsrange )), upper(CAST( ? AS tsrange ))

=cut

sub split_tsrange {
    my ( $dbh, $tsr ) = @_;

    my ( $result ) = $dbh->selectrow_array( 
        'SELECT lower(CAST( ? AS tsrange )), upper(CAST( ? AS tsrange ))',
        undef,
        $tsr, $tsr,
    ) if defined( $tsr );

    return $result;
}



=head2 canonicalize_ts

Given a string that might be a timestamp, "canonicalize" it by running it
through the database in the SQL statement:

    SELECT CAST( ? AS TIMESTAMP )

=cut

sub canonicalize_ts {
    my ( $dbh, $ts ) = @_;

    my ( $result ) = $dbh->selectrow_array( 
        'SELECT CAST( ? AS timestamp)',
        undef,
        $ts,
    ) if defined( $ts );

    return $result;
}


=head2 subtract_days

Given a timestamp and an integer n, subtract n days.

=cut

sub subtract_days {
    my ( $dbh, $ts, $n ) = @_;
    my $n_days = "$n days";
    my $sql = "SELECT TIMESTAMP ? - INTERVAL ?";
    my $sth = prepare( $sql );
    $sth->execute( $ts, $n_days );
    my ( $result ) = $sth->fetchrow_array;
    return $result;
}


=head2 tsrange_equal

Given two strings that might be equal tsranges, consult the database and return
the result (true or false).

=cut

sub tsrange_equal {
    my ( $dbh, $tr1, $tr2 ) = @_;

    my ( $result ) = $dbh->selectrow_array( 
        'SELECT CAST( ? AS tsrange) = CAST( ? AS tsrange )',
        undef,
        $tr1, $tr2
    );

    return $result;
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

