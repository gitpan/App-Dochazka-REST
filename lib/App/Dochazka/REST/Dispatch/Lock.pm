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
# Lock dispatcher/controller module
# ------------------------

package App::Dochazka::REST::Dispatch::Lock;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared qw( not_implemented pre_update_comparison );
use App::Dochazka::REST::Model::Lock;
use App::Dochazka::REST::Model::Shared;
use Data::Dumper;
use Params::Validate qw( :all );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Lock - path dispatch





=head1 VERSION

Version 0.290

=cut

our $VERSION = '0.290';




=head1 DESCRIPTION

Controller/dispatcher module for the 'Lock' resource. To determine
which functions in this module correspond to which resources, see.






=head1 RESOURCES

This section documents the resources whose dispatch targets are contained
in this source module - i.e., lock resources. For the resource
definitions, see C<config/dispatch/lock_Config.pm>.

Each resource can have up to four targets (one each for the four supported
HTTP methods GET, POST, PUT, and DELETE). That said, target routines may be
written to handle more than one HTTP method and/or more than one resoure.

=cut


# runtime generation of four routines: _get_default, _post_default,
# _put_default, _delete_default (top-level resource targets)
BEGIN {
    no strict 'refs';
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_INTERVAL', http_method => 'GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_INTERVAL', http_method => 'POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_INTERVAL', http_method => 'PUT' );
    *{"_delete_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_INTERVAL', http_method => 'DELETE' );
}


# 'lock/lid' and 'lock/lid/:lid' - only RUD supported (no create)
sub _lid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_lid" ); 
    my $lid;
    if ( $context->{'method'} eq 'POST' ) {
        return $CELL->status_err('DOCHAZKA_MALFORMED_400') unless exists $context->{'request_body'}->{'lid'};
        $lid = $context->{'request_body'}->{'lid'};
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING') unless $lid;
        delete $context->{'request_body'}->{'lid'};
    } else {
        $lid = $context->{'mapping'}->{'lid'};
    }

    # does the IID exist?
    my $status = App::Dochazka::REST::Model::Lock->load_by_lid( $lid );
    return $status unless $status->level eq 'OK' or $status->level eq 'NOTICE';
    return $CELL->status_notice( 'DISPATCH_IID_DOES_NOT_EXIST', args => [ $lid ] )
        if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';

    # it exists, so go ahead and do what we need to do
    if ( $context->{'method'} eq 'GET' ) {
        return $status if $status->code eq 'DISPATCH_RECORDS_FOUND';
    } elsif ( $context->{'method'} =~ m/^(PUT)|(POST)$/ ) {
        return _update_lock( $status->payload, $context->{'request_body'} );
    } elsif ( $context->{'method'} eq 'DELETE' ) {
        $log->notice( "Attempting to delete lock " . $status->payload->lid );
        return $status->payload->delete;
    }
    return $CELL->status_crit("Aaaaaaaaaaahhh! Swallowed by the abyss" );
}

# 'lock/new'
sub _new {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__. "::_lid" ); 

    # make sure request body with all required fields is present
    return $CELL->status_err('DOCHAZKA_MALFORMED_400') unless $context->{'request_body'};
    foreach my $missing_prop ( qw( aid intvl ) ) {
        if ( not exists $context->{'request_body'}->{$missing_prop} ) {
            return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ $missing_prop ] );
        }
    }

    # this resource requires special ACL handling
    my $current_eid = $context->{'current'}->{'eid'};
    my $current_priv = $context->{'current_priv'};
    if ( $current_priv eq 'passerby' or $current_priv eq 'inactive' ) {
        return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
    }
    if ( $context->{'request_body'}->{'eid'} ) {
        my $desired_eid = $context->{'request_body'}->{'eid'};
        if ( $desired_eid != $current_eid ) {
            return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' ) if $current_priv eq 'active';
        }
    } else {
        $context->{'request_body'}->{'eid'} = $current_eid;
    }

    # attempt to insert
    return _insert_lock( $context->{'request_body'} );
}

# takes two arguments:
# - "$lock" is an lock object (blessed hashref)
# - "$over" is a hashref with zero or more lock properties and new values
# the values from $over replace those in $int
sub _update_lock {
    my ($lock, $over) = @_;
    $log->debug("Entering " . __PACKAGE__ . "::_update_lock" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_MALFORMED_400')
    }
    delete $over->{'lid'} if exists $over->{'lid'};
    return $lock->update if pre_update_comparison( $lock, $over );
    return $CELL->status_err('DOCHAZKA_MALFORMED_400');
}

# takes PROPLIST
sub _insert_lock {
    my @ARGS = @_;
    $log->debug("Reached _insert_lock from " . (caller)[1] . " line " .  (caller)[2] . 
                " with argument list " . Dumper( \@ARGS) );

    # make sure we got an even number of arguments
    if ( @ARGS % 2 ) {
        return $CELL->status_crit( "Odd number of arguments passed to _insert_lock!" );
    }
    my %proplist_before = @ARGS;
    $log->debug( "Properties before filter: " . join( ' ', keys %proplist_before ) );
        
    # make sure we got something resembling a code
    foreach my $missing_prop ( qw( eid aid intvl ) ) {
        if ( not exists $proplist_before{$missing_prop} ) {
            return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ $missing_prop ] );
        }
    }

    # spawn an object, filtering the properties first
    my @filtered_args = App::Dochazka::Model::Lock::filter( @ARGS );
    my %proplist_after = @filtered_args;
    $log->debug( "Properties after filter: " . join( ' ', keys %proplist_after ) );
    my $int = App::Dochazka::REST::Model::Lock->spawn( @filtered_args );

    # execute the INSERT db operation
    return $int->insert;
}

1;
