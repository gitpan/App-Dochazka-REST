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
# dispatcher/controller module for 'schedule' resources
# ------------------------

package App::Dochazka::REST::Dispatch::Schedule;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared qw( not_implemented pre_update_comparison );
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Schedhistory qw( get_schedhistory );
use App::Dochazka::REST::Model::Schedintvls;
# import dispatch targets for 'schedule/all' and 'schedule/all/disabled'
use App::Dochazka::REST::Model::Schedule qw( schedule_all schedule_all_disabled );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;




=head1 NAME

App::Dochazka::REST::Dispatch::Schedule - path dispatch





=head1 VERSION

Version 0.263

=cut

our $VERSION = '0.263';




=head1 DESCRIPTION

Controller/dispatcher module for 'schedule' resources.






=head1 TARGET FUNCTIONS

The following functions implement targets for the various routes.

=cut

# /schedule/history/self
# /schedule/history/self/:tsrange
sub _history_self {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "_history_self" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'current'}->{'eid'};
    my $nick = $context->{'current'}->{'nick'};
    
    defined $tsrange
        ? get_schedhistory( eid => $eid, nick => $nick, tsrange => $tsrange )
        : get_schedhistory( eid => $eid, nick => $nick );
}


# /schedule
# /schedule/help
BEGIN {    
    no strict 'refs';
    # _get_default, _post_default, _put_default, _delete_default routines
    *{"_get_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_SCHEDULE', http_method => 'GET' );
    *{"_post_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_SCHEDULE', http_method => 'POST' );
    *{"_put_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_SCHEDULE', http_method => 'PUT' );
    *{"_delete_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_SCHEDULE', http_method => 'DELETE' );
}


# '/schedule/self/?:ts'
# '/schedule/eid/:eid/?:ts'
# '/schedule/nick/:nick/?:ts'
sub _current_schedule {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . ":_current_schedule" ); 
    return App::Dochazka::REST::Dispatch::Shared::current( 'schedule', $context );
}


# '/schedule/intervals/:sid'
sub _intervals_get {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . ":_intervals_get" ); 

    my $sid;
    if ( exists $context->{'mapping'}->{'sid'} ) {
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) 
            unless $context->{'mapping'}->{'sid'};
        $sid = $context->{'mapping'}->{'sid'};
    }
    return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) unless $sid;

    my $status = App::Dochazka::REST::Model::Schedule->load_by_sid( $sid );
    return $status;
}

# '/schedule/intervals'
# '/schedule/intervals/:sid'
sub _intervals_post {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . ":_intervals_post" ); 
    my ( $status, $code );

    # first, spawn a Schedintvls object
    my $intvls = App::Dochazka::REST::Model::Schedintvls->spawn;
    $log->debug( "Spawned Schedintvls object " . Dumper( $intvls ) );

    # note that a SSID has been assigned
    my $ssid = $intvls->ssid;
    $log->debug("Spawned Schedintvls object with SSID $ssid");

    # the request body should contain an array of time intervals:
    # put these into the object
    if ( ref( $context->{'request_body'} ) eq 'ARRAY' ) {
        #
        # assume that these are the intervals
        $intvls->{'intvls'} = $context->{'request_body'};
        #
        # insert the intervals
        $status = $intvls->insert;
        return $status unless $status->ok;
        #
        # convert the intervals to get the 'schedule' property
        $status = $intvls->load;
        return $status unless $status->ok;
        #
        # spawn Schedule object
        my $sched = App::Dochazka::REST::Model::Schedule->spawn(
            'schedule' => $intvls->json,
        );
        #
        # insert schedule object to get SID
        $status = $sched->insert;
        return $status unless $status->ok;
        if ( $status->code eq 'DOCHAZKA_SCHEDULE_EXISTS' ) {
            $code = 'DISPATCH_SCHEDULE_OK';
        } elsif ( $status->code eq 'DOCHAZKA_CUD_OK' ) {
            $code = 'DISPATCH_SCHEDULE_INSERT_OK';
        } else {
            die( 'AAAAAAAAHHHHH! Swallowed by the abyss' );
        }
        #
        # delete the schedintvls object
        $status = $intvls->delete;
        return $status unless $status->ok;
        #
        # report success
        return $CELL->status_ok( $code, payload => $sched->TO_JSON );
    } else {
        return $CELL->status_err( 'DISPATCH_SCHEDINTVLS_MISSING' );
    }

}

# '/schedule/intervals/:sid'
sub _schedule_post {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . ":_schedule_post" ); 

    # get SID
    my $sid;
    if ( exists $context->{'mapping'}->{'sid'} ) {
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) 
            unless $context->{'mapping'}->{'sid'};
        $sid = $context->{'mapping'}->{'sid'};
    }
    return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) unless $sid;

    # load the SID
    my $status = App::Dochazka::REST::Model::Schedule->load_by_sid( $sid );
    return $status unless $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND';

    # run the update operation
    return _update_schedule( $status->payload, $context->{'request_body'} );
}

# '/schedule/intervals'
# '/schedule/intervals/:sid'
sub _intervals_delete {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . ":_intervals_delete" ); 
    my ( $status, $sid );

    # get SID
    if ( exists $context->{'mapping'}->{'sid'} ) {
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) 
            unless $context->{'mapping'}->{'sid'};
        $sid = $context->{'mapping'}->{'sid'};
    } elsif ( exists $context->{'request_body'}->{'sid'} ) {
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) 
            unless $context->{'request_body'}->{'sid'};
        $sid = $context->{'request_body'}->{'sid'};
    }
    return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'sid' ] ) unless $sid;

    # spawn and load the schedule object
    $status = App::Dochazka::REST::Model::Schedule->load_by_sid( $sid );
    return $status unless $status->ok;
    return $status if $status->code ne 'DISPATCH_RECORDS_FOUND';
    my $sched = $status->payload;

    # delete the object
    $status = $sched->delete;
    return $status;

}


# takes two arguments:
# - "$sched" is a schedule object (blessed hashref)
# - "$over" is a hashref with zero or more schedule properties and new values
# the values from $over replace those in $emp
sub _update_schedule {
    my ($sched, $over) = @_;
    $log->debug("Entering App::Dochazka::REST::Dispatch::Schedule::_update_schedule" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_BAD_INPUT')
    }
    delete $over->{'sid'} if exists $over->{'sid'};
    delete $over->{'schedule'} if exists $over->{'schedule'};
    if ( pre_update_comparison( $sched, $over ) ) {
        $log->debug( "After pre_update_comparison: " . Dumper $sched );
        return $sched->update;
    }
    return $CELL->status_err('DOCHAZKA_BAD_INPUT');
}


1;
