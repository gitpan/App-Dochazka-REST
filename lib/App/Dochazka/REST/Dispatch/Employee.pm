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
use App::Dochazka::REST::Model::Shared qw( noof );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Employee - path dispatch





=head1 VERSION

Version 0.173

=cut

our $VERSION = '0.173';




=head1 DESCRIPTION

Controller/dispatcher module for the 'employee' resource.






=head1 TARGET FUNCTIONS

The following functions implement targets for the various routes.


=head2 Default targets

=cut

BEGIN {
    no strict 'refs';
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_EMPLOYEE_GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_EMPLOYEE_POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_EMPLOYEE_PUT' );
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


=head2 PUT targets

=cut

# no parameter, everything in request body, nick required
sub _put_employee_body_with_nick_required {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    return $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', args => [ 'nick' ] ) 
        unless $context->{'request_body'}->{'nick'};
    delete $context->{'request_body'}->{'eid'} if exists $context->{'request_body'}->{'eid'};
    return _put_employee( %{ $context->{'request_body'} } );
}

# nick provided in path, rest in optional request body
sub _put_employee_nick_in_path {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my $nick = $context->{'mapping'}->{'nick'};
    die "AAAAAAAAAAHHHHH! Swallowed by the abyss" unless defined $nick and ref \$nick eq 'SCALAR';
    $context->{'request_body'}->{'nick'} = $nick;
    delete $context->{'request_body'}->{'eid'} if exists $context->{'request_body'}->{'eid'};
    return _put_employee( %{ $context->{'request_body'} } );
}

# no parameter, everything in request body, EID required
sub _put_employee_body_with_eid_required {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    return $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', args => [ 'eid' ] ) 
        unless $context->{'request_body'}->{'eid'};
    return _put_employee( %{ $context->{'request_body'} } );
}

# EID provided in path, rest in optional request body
sub _put_employee_eid_in_path {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my $eid = $context->{'mapping'}->{'eid'};
    die "AAAAAAAAAAHHHHH! Swallowed by the abyss" unless defined $eid and ref \$eid eq 'SCALAR';
    $context->{'request_body'}->{'eid'} = $eid;
    return _put_employee( %{ $context->{'request_body'} } );
}

sub _put_employee {
    my @ARGS = @_;
    my %ARGS;

    # validate arguments and convert them into employee object
    my $status = $CELL->status_ok;
    try {
        %ARGS = validate( @ARGS, { 
            eid =>      { tupe => SCALAR | UNDEF, optional => 1 },
            nick =>     { type => SCALAR },
            fullname => { type => SCALAR | UNDEF, optional => 1 },
            email =>    { type => SCALAR | UNDEF, optional => 1 },
            passhash => { type => SCALAR | UNDEF, optional => 1 },
            salt =>     { type => SCALAR | UNDEF, optional => 1 },
            remark =>   { type => SCALAR | UNDEF, optional => 1 },
        } );
    }
    catch {
        $status = $CELL->status_err( 'DISPATCH_PUT_EMPLOYEE: %s', args => [ $_ ] );
    };
    return $status unless $status->ok;
    my $emp = App::Dochazka::REST::Model::Employee->spawn( %ARGS );

    # execute the INSERT/UPDATE database transaction
    my ( $level, $code );
    # if EID provided, we try to update
    if ( my $eid = $emp->eid ) {
        $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
        return ( $status->code eq 'DISPATCH_RECORDS_FOUND' )
            ? $emp->update
            : $CELL->status_err( 'DISPATCH_EID_DOES_NOT_EXIST', args => [ $eid ] );
    }
    # if nick provided, we either update if nick exists or insert otherwise
    elsif ( my $nick = $emp->nick ) {
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        if ( $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            $emp->eid( $status->payload->eid );
            return $emp->update;
        } else {
            return $emp->insert;
        }
    }
    # neither EID nor nick provided: ERROR
    return $CELL->status_err( 'DISPATCH_EMPLOYEE_PLEASE_PROVIDE_EID_OR_NICK' );
}


1;
