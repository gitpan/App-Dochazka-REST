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

# ------------------------
# dispatcher/controller module for 'priv' resources
# ------------------------

package App::Dochazka::REST::Dispatch::Priv;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;




=head1 NAME

App::Dochazka::REST::Dispatch::Priv - path dispatch





=head1 VERSION

Version 0.265

=cut

our $VERSION = '0.265';




=head1 DESCRIPTION

Controller/dispatcher module for the 'privhistory' resource.






=head1 TARGET FUNCTIONS

The following functions implement targets for the various routes.

=cut

# /priv/history/self
# /priv/history/self/:tsrange
sub _history_self {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_history_self" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'current'}->{'eid'};
    my $nick = $context->{'current'}->{'nick'};
    
    defined $tsrange
        ? get_privhistory( eid => $eid, nick => $nick, tsrange => $tsrange )
        : get_privhistory( eid => $eid, nick => $nick );
}

BEGIN {    
    no strict 'refs';
    # dynamically generate four routines: _get_default, _post_default,
    # _put_default, _delete_default
    *{"_get_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_PRIV', http_method => 'GET' );
    *{"_post_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_PRIV', http_method => 'POST' );
    *{"_put_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_PRIV', http_method => 'PUT' );
    *{"_delete_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_PRIV', http_method => 'DELETE' );
}


sub _current_priv {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Priv::_current_priv" ); 
    return App::Dochazka::REST::Dispatch::Shared::current( 'priv', $context );
}


# code common to _history_eid and _history_nick
# GET: get privhistory of an arbitrary EID over a tsrange that defaults to [,)
# PUT: insert a privhistory record
# DELETE: delete a privhistory record
#
sub _history_end_game {
    my ( $method, $eid, $nick, $tsrange, $body ) = @_;
    if ( $method eq 'GET' ) { 
        return ( defined $tsrange )
            ? get_privhistory( eid => $eid, nick => $nick, tsrange => $tsrange )
            : get_privhistory( eid => $eid, nick => $nick );
    } elsif ( $method eq 'PUT' ) {
        return _insert( $eid, $body );
    } elsif ( $method eq 'DELETE' ) {
        return _delete( $eid, $body );
    }
    die "AAAAAAHHHHHH!";
}

sub _history_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_history_eid" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'mapping'}->{'eid'};

    # display error if employee doesn't exist
    my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $emp = $status->payload;
        return _history_end_game( 
            $context->{'method'}, 
            $emp->eid, 
            $emp->nick, 
            $tsrange, 
            $context->{request_body} 
        );
    } elsif ( $status->level eq 'NOTICE' ) {
        return $CELL->status_err( 'DISPATCH_EID_DOES_NOT_EXIST', args => [ $eid ] );
    }
    return $status;
}

sub _history_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_history_nick" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $nick = $context->{'mapping'}->{'nick'};

    # display error if nick doesn't exist
    my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $emp = $status->payload;
        return _history_end_game( 
            $context->{'method'}, 
            $emp->eid, 
            $emp->nick, 
            $tsrange, 
            $context->{request_body} 
        );
    } elsif ( $status->level eq 'NOTICE' ) {
        return $CELL->status_err( 'DISPATCH_NICK_DOES_NOT_EXIST', args => [ $nick ] );
    }
    return $status;
}

sub _priv_by_phid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Priv::_priv_by_phid" ); 
    my $method = $context->{'method'};
    my $status;
    if ( my $phid = $context->{'mapping'}->{'phid'} ) {
        $status = App::Dochazka::REST::Model::Privhistory->load_by_phid( $phid );
        if ( $status->ok ) {
            if ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
                if ( $method =~ m/^delete/i ) {
                    if ( ref($status->payload) eq 'App::Dochazka::REST::Model::Privhistory' ) {
                        return $status->payload->delete;
                    }
                }
            }
        }
        return $status;
    }
    return $CELL->status_err("You must provide a valid PHID");
}

# takes eid (integer) and body (hashref)
sub _insert {
    my ( $eid, $body ) = @_;  
    return $CELL->status_err('DISPATCH_PRIVHISTORY_INVALID') if not $body->{'effective'} or not $body->{'priv'};
    my $pho;
    try {
        $pho = App::Dochazka::REST::Model::Privhistory->spawn( 
            eid => $eid, 
            effective => $body->{'effective'},
            priv => $body->{'priv'},
        );
    } catch {
        $log->crit($_);
        return $CELL->status_crit("DISPATCH_PRIVHISTORY_COULD_NOT_SPAWN", args => [ $_ ] );
    };
    return $pho->insert;
}

# takes eid (integer) and body (hashref)
sub _delete {
    my ( $eid, $body ) = @_;  
    delete $body->{'eid'} if exists $body->{'eid'};
    my ( $pho, $status );

    # if phid given, let it take precedence over everything else
    if ( exists $body->{'phid'} ) {
        $status = App::Dochazka::REST::Model::Privhistory->load_by_phid( $body->{'phid'} );
    # fall back to EID+effective
    } elsif ( exists $body->{'effective'} ) {
        $status = App::Dochazka::REST::Model::Privhistory->load_by_eid( $eid, $body->{'effective'} );
    } else {
        return $CELL->status_err( 'DISPATCH_NO_SUCH_PRIVHISTORY_RECORD' );
    }
    if ( $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err( 'DISPATCH_NO_SUCH_PRIVHISTORY_RECORD' );
    } elsif ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        # privhistory record MUST belong to the given EID
        if ( $status->payload->eid eq $eid ) {
            $pho = $status->payload;
            return $pho->delete;
        } else {
            return $CELL->status_err('DISPATCH_PRIVHISTORY_PHID_MISMATCH');
        }
    }
    return $status;
}

1;
