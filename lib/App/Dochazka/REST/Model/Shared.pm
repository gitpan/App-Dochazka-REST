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

package App::Dochazka::REST::Model::Shared;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use DBI;
use Try::Tiny;




=head1 NAME

App::Dochazka::REST::Model::Shared - functions shared by several modules within
the data model




=head1 VERSION

Version 0.066

=cut

our $VERSION = '0.066';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Shared;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=item * C<open_transaction>

=item * C<close_transaction>

=item * C<cud> (Create, Update, Delete -- for single-record statements only)

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( open_transaction close_transaction cud );




=head1 FUNCTIONS


=head2 open_transaction

Given a database handle, set AutoCommit to 0, RaiseError to 1.

=cut

sub open_transaction {
    my ( $dbh ) = @_;
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;
    return;
}


=head2 close_transaction

Given a database handle, set AutoCommit to 1, RaiseError to 0.

=cut

sub close_transaction {
    my ( $dbh ) = @_;
    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 0;
    return;
}


=head2 cud

** USE FOR SINGLE-RECORD SQL STATEMENTS ONLY **
Attempts to Create, Update, or Delete a single database record. Takes a blessed
reference (activity object or employee object), a SQL statement, and a list of
attributes. Overwrites attributes in the object with the RETURNING list values
received from the database. Returns a status object. Call example:

    $status = cud( $self, $sql, @attr );

=cut

sub cud {
    my ( $blessed, $sql, @attr ) = @_;
    my $dbh = $blessed->{dbh};
    my $status;
    return $CELL->status_err('DOCHAZKA_DB_NOT_ALIVE', args => [ 'cud' ] ) unless $dbh->ping;

    # check ACL: for now, we allow admins only 
    $log->debug( "Privilege level of EID " . $blessed->{acleid} . " is " . $blessed->{aclpriv} );
    return $CELL->status_err('DOCHAZKA_INSUFFICIENT_PRIV') unless $blessed->{aclpriv} eq 'admin';
    
    # DBI incantations
    open_transaction( $dbh );
    try {
        local $SIG{__WARN__} = sub {
                die @_;
            };
        my $sth = $dbh->prepare( $sql );
        my $counter = 0;
        map {
               $counter += 1;
               $sth->bind_param( $counter, $blessed->{$_} );
            } @attr;
        $sth->execute;
        my $rh = $sth->fetchrow_hashref;
        map { $blessed->{$_} = $rh->{$_}; } ( keys %$rh );
        $dbh->commit;
    } catch {
        my $errmsg = $_;
        $dbh->rollback;
        if ( not defined( $errmsg ) ) {
            $log->err( '$_ undefined in catch' );
            $errmsg = '<NONE>';
        }
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $errmsg ] );
    };
    close_transaction( $dbh );

    $status = $CELL->status_ok if not defined( $status );
    return $status;
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

