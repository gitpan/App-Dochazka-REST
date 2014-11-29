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
use App::Dochazka::REST::Dispatch::ACL qw( check_acl_context );
use App::Dochazka::REST::Dispatch::Shared qw( pre_update_comparison );
use App::Dochazka::REST::Model::Employee qw( noof_employees_by_priv );
use App::Dochazka::REST::Model::Shared qw( noof priv_by_eid schedule_by_eid );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Employee - path dispatch





=head1 VERSION

Version 0.322

=cut

our $VERSION = '0.322';




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
        $result = noof_employees_by_priv( lc $priv );
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
    my $current_sched = schedule_by_eid( $current_emp->{'eid'} );
    $CELL->status_ok( 
        'DISPATCH_EMPLOYEE_CURRENT_PRIV', 
        args => [ $current_emp->{'nick'}, $current_priv ], 
        payload => { 
            'priv' => $current_priv,
            'schedule' => $current_sched,
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
        
sub _put_post_delete_employee_by_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_put_post_delete_employee_by_eid with method " . $context->{'method'} );

    my $eid;
    $eid = $context->{'request_body'}->{'eid'} if $context->{'request_body'}->{'eid'};
    $eid = $context->{'mapping'}->{'eid'} if $context->{'mapping'}->{'eid'};
    $eid = $context->{'current'}->{'eid'} unless $eid;

    my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
    return _common_code( $context, $status );
}

sub _put_post_delete_employee_by_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my $cp = $context->{'current_priv'};
    $log->debug( "Entering " . __PACKAGE__ . "::_put_post_delete_employee_by_nick with method " . $context->{'method'} );

    my $nick;
    $nick = $context->{'request_body'}->{'nick'} if $context->{'request_body'}->{'nick'};
    $nick = $context->{'mapping'}->{'nick'} if $context->{'mapping'}->{'nick'};
    $nick = $context->{'current'}->{'nick'} unless $nick;

    my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
    if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        if ( $cp =~ m/^(inactive)|(active)$/i ) {
            if ( $nick ne $context->{'current'}->{'nick'} ) {
                return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
            }            
            delete $context->{'request_body'}->{'nick'};
        }
        return _common_code( $context, $status );
    } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        if ( $context->{'method'} =~ m/^(PUT)|(POST)$/ ) {
            # INSERT
            if ( $cp =~ m/^(inactive)|(active)$/i ) {
                return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
            }
            delete $context->{'request_body'}->{'nick'} if $context->{'request_body'}->{'nick'};
            return _insert_employee( 'nick' => $nick, %{ $context->{request_body} } );
        }
        return $CELL->status_err('DOCHAZKA_NOT_FOUND_404');
    }
    return $status;
}

sub _common_code {
    my ( $context, $status ) = @_;
    my $cp = $context->{'current_priv'};
    if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $this_emp = $status->payload;
        if ( $context->{'method'} =~ /^(PUT)|(POST)/i ) {
            #
            # 'inactive' and 'active' can only operate on their own EID
            if ( $cp =~ m/^(inactive)|(active)$/i and $this_emp->eid != $context->{'current'}->{'eid'} ) {
                return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
            }
            #
            # if privlevel is inactive or active, analyze which fields the user wants to update
            # (passerbies will be rejected earlier in Resource.pm, and admins can edit any field)
            if ( $cp =~ m/^(inactive)|(active)$/i ) {
                delete $context->{'request_body'}->{'eid'};
                my %lut;
                map { $lut{$_} = ''; } @{ $site->DOCHAZKA_PROFILE_EDITABLE_FIELDS->{$cp} };
                foreach my $prop ( keys %{ $context->{'request_body'} } ) {
                    next if exists $lut{$prop};
                    return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
                }
            }
            #
            # check that the request body is a hashref
            if ( ref( $context->{'request_body'} ) ne 'HASH' ) {
                return $CELL->status_err( 'DOCHAZKA_MALFORMED_400' );
            }
            #
            # ensure that the EID is not in the request body
            delete $context->{'request_body'}->{'eid'};
            #
            # run the update
            return _update_employee( $this_emp, $context->{'request_body'} );
        } elsif ( $context->{'method'} =~ m/^DELETE/i ) {
            # DELETE is only accessible to administrators (enforced by Resource.pm)
            $log->notice( "Attempting to delete employee with EID " . $this_emp->eid );
            return $this_emp->delete;
        }
    } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        if ( $cp =~ m/^(inactive)|(active)$/i ) {
            return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
        } 
        return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' );
    }
    # DBI error or other badness
    return $status;
}

# takes two arguments:
# - "$emp" is an employee object (blessed hashref)
# - "$over" is a hashref with zero or more employee properties and new values
# the values from $over replace those in $emp
sub _update_employee {
    my ($emp, $over) = @_;
    $log->debug("Entering " . __PACKAGE__ . "::_update_employee" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_MALFORMED_400')
    }
    delete $over->{'eid'} if exists $over->{'eid'};
    return $emp->update if pre_update_comparison( $emp, $over );
    return $CELL->status_err('DOCHAZKA_MALFORMED_400');
}


sub _get_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::Employee::_get_eid" ); 

    # EID the user wants
    my $eid = $context->{'mapping'}->{'eid'};

    # user's EID and privlevel
    my $current_eid = $context->{'current'}->{'eid'};
    my $current_priv = $context->{'current_priv'};

    # user might be an 'active', in which case he can only see his own EID
    if ( $current_priv ne 'admin' ) {
        if ( $eid != $current_eid ) {
            return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
        }
    }
    
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
