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

Version 0.271

=cut

our $VERSION = '0.271';




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

sub _history_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_history_eid" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $eid = $context->{'mapping'}->{'eid'};

    return App::Dochazka::REST::Dispatch::Shared::history(
        class => 'App::Dochazka::REST::Model::Privhistory',
        method => $context->{'method'},
        key => [ 'EID', $eid ],
        tsrange => $tsrange,
        body => $context->{'request_body'},
    );
}

sub _history_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_history_nick" ); 

    my $tsrange = $context->{'mapping'}->{'tsrange'};
    my $nick = $context->{'mapping'}->{'nick'};

    return App::Dochazka::REST::Dispatch::Shared::history(
        class => 'App::Dochazka::REST::Model::Privhistory',
        method => $context->{'method'},
        key => [ 'nick', $nick ],
        tsrange => $tsrange,
        body => $context->{'request_body'},
    );
}

sub _priv_by_phid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_priv_by_phid" ); 
    my $method = $context->{'method'};
    return App::Dochazka::REST::Dispatch::Shared::history_by_id(
        class => 'App::Dochazka::REST::Model::Privhistory',
        method => $context->{'method'},
        id => $context->{'mapping'}->{'phid'},
    );
}


1;
