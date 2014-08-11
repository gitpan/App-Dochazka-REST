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
# Privhistory dispatcher/controller module
# ------------------------

package App::Dochazka::REST::Dispatch::Privhistory;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Shared;
use App::Dochazka::REST::Model::Employee qw( eid_exists nick_exists );
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use Carp;
use Data::Dumper;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );




=head1 NAME

App::Dochazka::REST::Dispatch::Privhistory - path dispatch





=head1 VERSION

Version 0.154

=cut

our $VERSION = '0.154';




=head1 DESCRIPTION

Controller/dispatcher module for the 'privhistory' resource.






=head1 TARGET FUNCTIONS

The following functions implement targets for the various routes.

=cut

BEGIN {    
    no strict 'refs';
    *{"_get_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_PRIVHISTORY_GET' );
    *{"_post_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_PRIVHISTORY_POST' );
    *{"_put_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_PRIVHISTORY_PUT' );
}


sub _get_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_nick" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $nick = $context->{'mapping'}->{'nick'};

    # display error if nick doesn't exist
    my $emp = nick_exists( $nick );
    return $CELL->status_err( 'DISPATCH_NICK_DOES_NOT_EXIST', args => [ $nick ] ) if not defined( $emp );
    return $emp if $emp->isa( 'App::CELL::Status' ); # DBI error

    defined $tsrange
        ? get_privhistory( nick => $nick, tsrange => $tsrange )
        : get_privhistory( nick => $nick );
}

sub _get_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_eid" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'mapping'}->{'eid'};

    # display error if nick doesn't exist
    my $emp = eid_exists( $eid );
    return $CELL->status_err( 'DISPATCH_EID_DOES_NOT_EXIST', args => [ $eid ] ) if not defined( $emp );
    return $emp if $emp->isa( 'App::CELL::Status' ); # DBI error

    defined $tsrange
        ? get_privhistory( eid => $eid, tsrange => $tsrange )
        : get_privhistory( eid => $eid );
}

sub _get_current {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_current" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'current'}->{'eid'};
    my $nick = $context->{'current'}->{'nick'};
    
    defined $tsrange
        ? get_privhistory( eid => $eid, nick => $nick, tsrange => $tsrange )
        : get_privhistory( eid => $eid, nick => $nick );
}

1;
