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
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use Carp;
use Data::Dumper;
use Path::Router;
use Scalar::Util qw( blessed );

use parent 'App::Dochazka::REST::Dispatch';




=head1 NAME

App::Dochazka::REST::Dispatch::Privhistory - path dispatch





=head1 VERSION

Version 0.114

=cut

our $VERSION = '0.114';




=head1 DESCRIPTION

Controller/dispatcher module for the 'privhistory' resource.






=head1 FUNCTIONS

=head2 _init_get

Adds employee-related routes to C<$router_get> (router for GET requests).

=cut

sub _init_get {

    my $router_get = __PACKAGE__->SUPER::router( 'GET' );
    die "Bad Path::Router object" unless $router_get->isa( 'Path::Router' );

    $router_get->add_route( 'privhistory',
        target => \&_get_default,
    );

    $router_get->add_route( 'privhistory/help',
        target => \&_get_default,
    );

    $router_get->add_route( 'privhistory/current',
        target => \&_get_privhistory,
    );

    $router_get->add_route( 'privhistory/current/:param',
        target => \&_get_privhistory,
    );

    return "Privhistory GET router initialization complete";   
}


=head2 _init_post

Adds employee-related routes to C<$router_post> (router for POST requests).

=cut

sub _init_post {
    my $router_post = __PACKAGE__->SUPER::router( 'POST' );
    return "Employee POST router initialization complete";   
}




=head1 TARGET FUNCTIONS

The following functions implement actions for the various routes.

=cut

    
sub _get_default {
    my ( %ARGS ) = @_;

    # ACL check (ACL status of this function is 'passerby')
    if ( exists $ARGS{'acleid'} and exists $ARGS{'aclpriv'} ) {
        return $CELL->status_ok( 'DISPATCH_ACL_CHECK_OK' );
    }

    my $uri = $ARGS{'context'}->{'uri'};
    $uri =~ s/\/*$//;
    my $server_status = App::Dochazka::REST::dbh::status;
    return $CELL->status_ok(
        'DISPATCH_EMPLOYEE_DEFAULT',
        args => [ $VERSION, $server_status ],
        payload => {
            documentation => $site->DOCHAZKA_DOCUMENTATION_URI,
            resources => {
                'current' => {
                    link => "$uri/privhistory/current",
                    description => 'Get entire history of privilege level changes for the current employee',
                },
                'current/:param' => {
                    link => "$uri/privhistory/current/:param",
                    description => 'Get partial history of privilege level changes for the current employee (i.e, limit to tsrange given in param)',
                },
            },
        },
    );
}


sub _get_privhistory {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_privhistory" ); 

    # ACL status of this target is 'active'
    if ( exists $ARGS{'acleid'} and exists $ARGS{'aclpriv'} ) {
        my $priv = $ARGS{'aclpriv'};
        return $CELL->status_ok( 'DISPATCH_ACL_CHECK_OK' ) if $priv eq 'active' or $priv eq 'admin';
        return $CELL->status_not_ok;
    }

    my $tsrange = $ARGS{'context'}->{'mapping'}->{'param'};
    my $eid = $ARGS{'context'}->{'current'}->{'eid'};
    my $nick = $ARGS{'context'}->{'current'}->{'nick'};
    my $status = get_privhistory( $eid, $tsrange );
    if ( $status->ok ) {
        # The payload will be an array reference
        my $arrayref = $status->payload;
        my $new_payload = { 
            eid => $eid,
            nick => $nick,
            privhistory => $arrayref 
        };
        $status->payload( $new_payload );
    }
    #if ( $status->payload ) {
    #    foreach my $pho ( @{ $status->payload } ) {
    #        $pho = $pho->expurgate;
    #    }
    #    my $count = @{ $status->payload };
    #    $status->payload( $status->{'payload'}->[0] ) if $count == 1;
    #}
    return $status;
}

1;
