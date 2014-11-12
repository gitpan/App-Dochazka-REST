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
# Employee dispatcher/controller module
# ------------------------

package App::Dochazka::REST::Dispatch::Employee;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared qw( pre_update_comparison );
use App::Dochazka::REST::Model::Employee qw( noof_employees_by_priv );
use App::Dochazka::REST::Model::Shared qw( noof priv_by_eid );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Employee - path dispatch





=head1 VERSION

Version 0.270

=cut

our $VERSION = '0.270';




=head1 DESCRIPTION

Controller/dispatcher module for the 'employee' resource. To determine
which functions in this module correspond to which resources, see.






=head1 RESOURCES

This section documents the resources whose dispatch targets are contained
in this source module - i.e., employee resources. For the resource
definitions, see C<config/dispatch/employee_Config.pm>.

Each resource can have up to four targets (one each for the four supported
HTTP methods GET, POST, PUT, and DELETE). That said, target routines may be
written to handle more than one HTTP method and/or more than one resoure.

=cut


sub _get_count {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_count" ); 

    my $result;
    if ( my $priv = $context->{'mapping'}->{'priv'} ) {;
        $result = noof_employees_by_priv( $priv );
    } else {
        $result = noof_employees_by_priv( 'total' );
    }
    return $result;
}


sub _get_current {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_current" ); 

    my $current_emp = $context->{'current'};
    $CELL->status_ok( 'DISPATCH_EMPLOYEE_CURRENT', args => 
        [ $current_emp->{'nick'} ], payload => $current_emp );
}


sub _get_current_priv {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_current_priv" ); 

    my $current_emp = $context->{'current'};
    my $current_priv = priv_by_eid( $current_emp->{'eid'} );
    $CELL->status_ok( 
        'DISPATCH_EMPLOYEE_CURRENT_PRIV', 
        args => [ $current_emp->{'nick'}, $current_priv ], 
        payload => { 
            'priv' => $current_priv,
            'current_emp' => $current_emp,
        } 
    );
}


# a little piece of shared code
sub _assemble_employee_object {
    my %hr = @_;
    my %r;
    while (my ($key, $value) = each %hr) {
        if ( grep { $key eq $_ } ( 'eid', 'nick', 'fullname', 'email', 'passhash', 'salt', 'remark' ) ) {
            $r{$key} = $value;
        }
    }
    return %r;
}
        
# target function for POST employee/eid, PUT employee/eid/:eid, and 
# DELETE employee/eid/:eid
sub _put_post_delete_employee_by_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    $log->debug( "Entering _put_post_delete_employee_by_eid" );

    # get eid
    my $eid;
    if ( $context->{'method'} eq 'POST' ) {
        $eid = $context->{'request_body'}->{'eid'} if exists $context->{'request_body'}->{'eid'};
    } elsif ( $context->{'method'} =~ /^(PUT)|(DELETE)/i ) {
        $eid = $context->{'mapping'}->{'eid'} if exists $context->{'mapping'}->{'eid'};
    } else {
        return $CELL->status_err( 'DISPATCH_UNSUPPORTED_HTTP_METHOD %s', args => [ $context->{'method'} ] );
    }

    if ( defined($eid) and $eid =~ m/^\d+$/ ) {
        my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
        if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            if ( $context->{'method'} =~ /^(PUT)|(POST)/i ) {
                #my $oldemp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );
                my $oldemp = $status->payload;
                return _update_employee( $oldemp, $context->{'request_body'} );
            } elsif ( $context->{'method'} =~ /^DELETE/i ) {
                $log->notice("Attempting to delete employee with EID $eid");
                return $status->payload->delete;  # employee object is in the payload
            }
        } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
            return $CELL->status_err( 'DISPATCH_EID_DOES_NOT_EXIST', args => [ $eid ] );
        }
        # DBI error or other badness
        return $status;
    } else {
        return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'eid' ] ); 
    }
}

# takes two arguments:
# - "$emp" is an employee object (blessed hashref)
# - "$over" is a hashref with zero or more employee properties and new values
# the values from $over replace those in $emp
sub _update_employee {
    my ($emp, $over) = @_;
    $log->debug("Entering App::Dochazka::REST::Dispatch::Employee::_update_employee" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_BAD_INPUT')
    }
    delete $over->{'eid'} if exists $over->{'eid'};
    return $emp->update if pre_update_comparison( $emp, $over );
    return $CELL->status_err('DOCHAZKA_BAD_INPUT');
}


sub _get_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_eid" ); 

    my $eid = $context->{'mapping'}->{'eid'};
    App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
}

# for PUT employee/eid/:eid, see the _put_post_delete_employee_by_eid routine, above


# runtime generation of four routines: _get_default, _post_default,
# _put_default, _delete_default (top-level resource targets)
BEGIN {
    no strict 'refs';
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'PUT' );
    *{"_delete_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'DELETE' );
}


sub _put_post_delete_employee_by_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    $log->debug( 'Entering _put_post_delete_employee_by_nick with method ' . $context->{'method'} );

    # get nick
    my $nick;
    if ( $context->{'method'} eq 'POST' ) {
        $nick = $context->{'request_body'}->{'nick'} if exists $context->{'request_body'}->{'nick'};
        # they have no business sending an 'eid' property...
        delete $context->{'request_body'}->{'eid'} if exists $context->{'request_body'}->{'eid'};
    } elsif ( $context->{'method'} =~ /^(PUT)|(DELETE)/ ) {
        $nick = $context->{'mapping'}->{'nick'} if exists $context->{'mapping'}->{'nick'};
    } else {
        return $CELL->status_err( 'DISPATCH_UNSUPPORTED_HTTP_METHOD %s', args => [ $context->{'method'} ] );
    }

    if ( $nick ) {
        my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        if ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            if ( $context->{'method'} =~ /^(PUT)|(POST)/ ) {
                #my $oldemp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );
                my $oldemp = $status->payload;
                _update_employee( $oldemp, $context->{'request_body'} );
            } elsif ( $context->{'method'} eq 'DELETE' ) {
                $log->notice("Attempting to delete employee $nick");
                return $status->payload->delete;  # employee object is in the payload
            }
        } else {
            if ( $context->{'method'} =~ /^(PUT)|(POST)/ ) {
                delete $context->{'request_body'}->{'nick'} if exists $context->{'request_body'}->{'nick'};
                _insert_employee( _assemble_employee_object( nick => $nick, %{ $context->{'request_body'} } ) );
            } elsif ( $context->{'method'} eq 'DELETE' ) {
                $log->error("Not attempting to delete non-existent employee $nick" );
                return $CELL->status_err('DISPATCH_NICK_DOES_NOT_EXIST', args => [ $nick ] );
            }
        }
    } else {
        return $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', args => [ 'nick' ] ); 
    }
}

# takes PROPLIST; 'nick' property is mandatory and must be first in the list
sub _insert_employee {
    my @ARGS = @_;
    $log->debug("Reached _insert_employee from " . (caller)[1] . " line " .  (caller)[2] . 
                " with argument list " . Dumper( \@ARGS ) );

    # make sure we got an even number of arguments
    if ( @ARGS % 2 ) {
        return $CELL->status_crit( "Odd number of arguments passed to _insert_employee!" );
    }
    my %proplist_before = @ARGS;
    $log->debug( "Properties before filter: " . join( ' ', keys %proplist_before ) );
        
    # make sure we got something resembling a nick
    if ( not exists $proplist_before{'nick'} ) {
        return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ 'nick' ] );
    }

    # spawn an object, filtering the properties first
    my @filtered_args = App::Dochazka::Model::Employee::filter( @ARGS );
    my %proplist_after = @filtered_args;
    $log->debug( "Properties after filter: " . join( ' ', keys %proplist_after ) );
    my $emp = App::Dochazka::REST::Model::Employee->spawn( @filtered_args );

    # execute the INSERT db operation
    return $emp->insert;
}


sub _get_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_nick with mapping " . Dumper $context->{'mapping'} ); 

    my $nick = $context->{'mapping'}->{'nick'};

    return App::Dochazka::REST::Model::Employee->load_by_nick( $nick ) 
        unless $nick =~ m/%/;
    
    my $status = App::Dochazka::REST::Model::Employee->
        select_multiple_by_nick( $nick );
    foreach my $emp ( @{ $status->payload->{'result_set'} } ) {
        $emp = $emp->TO_JSON;
    }
    return $status;
}

1;
