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
# Activity dispatcher/controller module
# ------------------------

package App::Dochazka::REST::Dispatch::Activity;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared qw( not_implemented pre_update_comparison );
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Model::Shared;
use Data::Dumper;
use Params::Validate qw( :all );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Activity - path dispatch





=head1 VERSION

Version 0.264

=cut

our $VERSION = '0.264';




=head1 DESCRIPTION

Controller/dispatcher module for the 'activity' resource. To determine
which functions in this module correspond to which resources, see.






=head1 RESOURCES

This section documents the resources whose dispatch targets are contained
in this source module - i.e., activity resources. For the resource
definitions, see C<config/dispatch/activity_Config.pm>.

Each resource can have up to four targets (one each for the four supported
HTTP methods GET, POST, PUT, and DELETE). That said, target routines may be
written to handle more than one HTTP method and/or more than one resoure.

=cut


# runtime generation of four routines: _get_default, _post_default,
# _put_default, _delete_default (top-level resource targets)
BEGIN {
    no strict 'refs';
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_ACTIVITY', http_method => 'GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_ACTIVITY', http_method => 'POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_ACTIVITY', http_method => 'PUT' );
    *{"_delete_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_ACTIVITY', http_method => 'DELETE' );
}


#sub _get_all {
#    $log->debug( "Entering App::Dochazka::REST::Dispatch::Activity::_get_all" ); 
#    my $bool = $context->{'mapping'}->{'bool'};
#    # we don't need to examine $bool too much, because Perl will evaluate it in boolean context
#    return App::Dochazka::REST::Model::Activity::get_all_activities( disabled => $bool );
#}

# 'activity/all'
sub _get_all_without_disabled {
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Activity::_get_all_without_disabled" ); 
    return App::Dochazka::REST::Model::Activity::get_all_activities( disabled => 0 );
}

# 'activity/all/disabled'
sub _get_all_including_disabled {
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Activity::_get_all_including_disabled" ); 
    return App::Dochazka::REST::Model::Activity::get_all_activities( disabled => 1 );
}

# 'activity/aid' and 'activity/aid/:aid' - only RUD supported (no create)
sub _aid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Activity::_aid" ); 
    my $aid;
    if ( $context->{'method'} eq 'POST' ) {
        return $CELL->status_err('DOCHAZKA_BAD_INPUT') unless exists $context->{'request_body'}->{'aid'};
        $aid = $context->{'request_body'}->{'aid'};
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING') unless $aid;
        delete $context->{'request_body'}->{'aid'};
    } else {
        $aid = $context->{'mapping'}->{'aid'};
    }

    # does the AID exist?
    my $status = App::Dochazka::REST::Model::Activity->load_by_aid( $aid );
    return $status unless $status->level eq 'OK' or $status->level eq 'NOTICE';
    return $CELL->status_notice( 'DISPATCH_AID_DOES_NOT_EXIST', args => [ $aid ] )
        if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';

    # it exists, so go ahead and do what we need to do
    if ( $context->{'method'} eq 'GET' ) {
        return $status if $status->code eq 'DISPATCH_RECORDS_FOUND';
    } elsif ( $context->{'method'} =~ m/^(PUT)|(POST)$/ ) {
        return _update_activity( $status->payload, $context->{'request_body'} );
    } elsif ( $context->{'method'} eq 'DELETE' ) {
        $log->notice( "Attempting to delete activity " . $status->payload->aid );
        return $status->payload->delete;
    }
    return $CELL->status_crit("Aaaaaaaaaaahhh! Swallowed by the abyss" );
}

# 'activity/code' and 'activity/code/:code' - full CRUD supported
sub _code {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Activity::_code" ); 
    my $code;
    if ( $context->{'method'} eq 'POST' ) {
        return $CELL->status_err('DOCHAZKA_BAD_INPUT') unless exists $context->{'request_body'}->{'code'};
        $code = $context->{'request_body'}->{'code'};
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING') unless $code;
        delete $context->{'request_body'}->{'code'};
    } else {
        $code = $context->{'mapping'}->{'code'};
    }
    # does the code exist?
    my $status = App::Dochazka::REST::Model::Activity->load_by_code( $code );
    return $status unless $status->level eq 'OK' or $status->level eq 'NOTICE';

    if ( $context->{'method'} eq 'GET' ) {
        return $CELL->status_notice( 'DISPATCH_CODE_DOES_NOT_EXIST', args => [ $code ] )
            if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';
        return $status if $status->code eq 'DISPATCH_RECORDS_FOUND';
    } 
    elsif ( $context->{'method'} =~ m/^(PUT)|(POST)$/ ) {
        return _insert_activity( code => $code, %{ $context->{'request_body'} } )
            if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';
        return _update_activity( $status->payload, $context->{'request_body'} )
            if $status->code eq 'DISPATCH_RECORDS_FOUND';
    } 
    elsif ( $context->{'method'} eq 'DELETE' ) {
        return $CELL->status_notice( 'DISPATCH_CODE_DOES_NOT_EXIST', args => [ $code ] )
            if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';
        $log->notice( "Attempting to delete activity " . $status->payload->code );
        return $status->payload->delete;
    }

    return $CELL->crit("Aaaaaaaaaaahhh! Swallowed by the abyss" );
}

# takes two arguments:
# - "$act" is an activity object (blessed hashref)
# - "$over" is a hashref with zero or more activity properties and new values
# the values from $over replace those in $act
sub _update_activity {
    my ($act, $over) = @_;
    $log->debug("Entering App::Dochazka::REST::Dispatch::Activity::_update_activity" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_BAD_INPUT')
    }
    delete $over->{'aid'} if exists $over->{'aid'};
    return $act->update if pre_update_comparison( $act, $over );
    return $CELL->status_err('DOCHAZKA_BAD_INPUT');
}

# takes PROPLIST; 'code' property is mandatory and must be first in the list
sub _insert_activity {
    my @ARGS = @_;
    $log->debug("Reached _insert_activity from " . (caller)[1] . " line " .  (caller)[2] . 
                " with argument list " . Dumper( \@ARGS) );

    # make sure we got an even number of arguments
    if ( @ARGS % 2 ) {
        return $CELL->status_crit( "Odd number of arguments passed to _insert_activity!" );
    }
    my %proplist_before = @ARGS;
    $log->debug( "Properties before filter: " . join( ' ', keys %proplist_before ) );
        
    # make sure we got something resembling a code
    if ( not exists $proplist_before{'code'} ) {
        return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'code' ] );
    }

    # spawn an object, filtering the properties first
    my @filtered_args = App::Dochazka::Model::Activity::filter( @ARGS );
    my %proplist_after = @filtered_args;
    $log->debug( "Properties after filter: " . join( ' ', keys %proplist_after ) );
    my $act = App::Dochazka::REST::Model::Activity->spawn( @filtered_args );

    # execute the INSERT db operation
    return $act->insert;
}

1;
