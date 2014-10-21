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
use App::Dochazka::REST::Dispatch::Shared;
use App::Dochazka::REST::Model::Employee qw( nick_exists noof_employees_by_priv );
use App::Dochazka::REST::Model::Shared qw( noof priv_by_eid );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Employee - path dispatch





=head1 VERSION

Version 0.195

=cut

our $VERSION = '0.195';




=head1 DESCRIPTION

Controller/dispatcher module for the 'employee' resource. To determine
which functions in this module correspond to which resources, see.






=head1 TARGET FUNCTIONS

The following functions implement targets for the various routes.


=head2 Default targets

=cut

BEGIN {
    no strict 'refs';
    # dynamically generate four routines: _get_default, _post_default,
    # _put_default, _delete_default
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'PUT' );
    *{"_delete_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_EMPLOYEE', http_method => 'DELETE' );
}

=head2 GET targets

=cut

sub _get_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_nick with mapping " . Dumper $context->{'mapping'} ); 

    my $nick = $context->{'mapping'}->{'nick'};

    return App::Dochazka::REST::Model::Employee->load_by_nick( $nick ) 
        unless $nick =~ m/%/;
    
    my $status = App::Dochazka::REST::Model::Employee->
        select_multiple_by_nick( $nick );
    foreach my $emp ( @{ $status->payload->{'result_set'} } ) {
        $emp = $emp->expurgate;
    }
    return $status;
}

sub _get_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_eid" ); 

    my $eid = $context->{'mapping'}->{'eid'};
    App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
}


sub _get_current {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_current" ); 

    my $current_emp = $context->{'current'};
    $CELL->status_ok( 'DISPATCH_EMPLOYEE_CURRENT', args => 
        [ $current_emp->{'nick'} ], payload => $current_emp );
}


sub _get_current_priv {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_current_priv" ); 

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


sub _get_count {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_count" ); 

    my $result;
    if ( my $priv = $context->{'mapping'}->{'priv'} ) {;
        $result = noof_employees_by_priv( $priv );
    } else {
        $result = noof_employees_by_priv( 'total' );
    }
    return $result;
}


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
        
sub _put_post_employee_by_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    # get nick
    my $nick;
    if ( $context->{'method'} eq 'POST' ) {
        $nick = $context->{'request_body'}->{'nick'} if exists $context->{'request_body'}->{'nick'};
    } elsif ( $context->{'method'} eq 'PUT' ) {
        $nick = $context->{'mapping'}->{'nick'} if exists $context->{'mapping'}->{'nick'};
    } else {
        return $CELL->status_err( 'DISPATCH_UNSUPPORTED_HTTP_METHOD %s', args => [ $context->{'method'} ] );
    }

    if ( $nick ) {
        my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        if ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            my $oldemp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );
            my $newemp = App::Dochazka::REST::Model::Employee->spawn(
                _assemble_employee_object( %{ $context->{'request_body'} } ) 
            );
            _update_employee( $oldemp, $newemp );
        } else {
            _insert_employee( _assemble_employee_object( nick => $nick, %{ $context->{'request_body'} } ) );
        }
    } else {
        return $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', args => [ 'nick' ] ); 
    }
}

sub _put_post_employee_by_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    # get eid
    my $eid;
    if ( $context->{'method'} eq 'POST' ) {
        $eid = $context->{'request_body'}->{'eid'} if exists $context->{'request_body'}->{'eid'};
    } elsif ( $context->{'method'} eq 'PUT' ) {
        $eid = $context->{'mapping'}->{'eid'} if exists $context->{'mapping'}->{'eid'};
    } else {
        return $CELL->status_err( 'DISPATCH_UNSUPPORTED_HTTP_METHOD %s', args => [ $context->{'method'} ] );
    }

    if ( $eid ) {
        my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
        if ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            my $oldemp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );
            my $newemp = App::Dochazka::REST::Model::Employee->spawn(
                _assemble_employee_object( %{ $context->{'request_body'} } ) 
            );
            _update_employee( $oldemp, $newemp );
        } else {
            return $CELL->status_err( 'DISPATCH_EID_DOES_NOT_EXIST', $eid );
        }
    } else {
        return $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', args => [ 'eid' ] ); 
    }
}

# takes PROPLIST with mandatory 'nick' property
sub _insert_employee {
    my @ARGS = @_;
    $log->debug("Reached _insert_employee from " . (caller)[1] . " line " .  (caller)[2] . " with argument list " . join( ", ", @ARGS ) );

    # validate arguments and convert them into employee object
    my $status = $CELL->status_ok;
    my %ARGS;
    try {
        %ARGS = validate( @ARGS, { 
            nick =>     { type => SCALAR },
            fullname => { type => SCALAR | UNDEF, optional => 1 },
            email =>    { type => SCALAR | UNDEF, optional => 1 },
            passhash => { type => SCALAR | UNDEF, optional => 1 },
            salt =>     { type => SCALAR | UNDEF, optional => 1 },
            remark =>   { type => SCALAR | UNDEF, optional => 1 },
        } );
    }
    catch {
        $status = $CELL->status_err( 'DISPATCH_INSERT_EMPLOYEE: %s', args => [ $_ ] );
    };
    return $status unless $status->ok;
    my $emp = App::Dochazka::REST::Model::Employee->spawn( %ARGS );
    return $emp->insert;
}

# takes "emp" and "over" employee objects - $emp is overlayed by $over
sub _update_employee {
    my ($emp, $over) = @_;

    $emp->overlay( $over ); # note that 'overlay' does not change EID
    return $emp->update;
}

1;
