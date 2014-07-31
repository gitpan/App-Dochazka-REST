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
# Path dispatcher module
# ------------------------

package App::Dochazka::REST::Dispatch;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Employee;
use App::Dochazka::REST::Dispatch::Privhistory;
use Carp;
use Data::Dumper;
use Path::Router;
use Scalar::Util qw( blessed );

use parent 'App::Dochazka::REST::Resource';




=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.125

=cut

our $VERSION = '0.125';




=head1 DESCRIPTION

This module contains functions that deal with path dispatch, or path routing --
i.e. processing the "path" from the HTTP request. 




=head1 FUNCTIONS


=head2 init

Takes method and runs the router initialization routine for that method.

=cut

sub init {
    my ( $class, $method ) = @_;
    die "Method not defined" unless defined $method;
    $method = uc $method;
    return _init_get() if $method eq 'GET';
    return _init_post() if $method eq 'POST';
}


sub _init_get {

    my $router_get = __PACKAGE__->SUPER::_router_get( Path::Router->new );
    die "Bad Path::Router object" unless $router_get->isa( 'Path::Router' );

    $router_get->add_route( '',
        defaults => {
            acl_profile => 'passerby',
        },
        target => \&_get_default,
    );

    $router_get->add_route( 'help',
        defaults => {
            acl_profile => 'passerby',
        },
        target => \&_get_default,
    );

    $router_get->add_route( 'version',
        defaults => {
            acl_profile => 'passerby',
        },
        target => \&_get_default,
    );
   
    $router_get->add_route( 'forbidden',
        # special case: ACL profile is undefined; ACL check will always fail
        target => \&_get_forbidden,
    );
   
    $router_get->add_route( 'siteparam/:param',
        defaults => {
            acl_profile => 'admin',
        },
        target => \&_get_site_param,
    );
   
    foreach my $controller ( @{ $site->DISPATCH_CONTROLLERS } ) {
        my $exp = 'App::Dochazka::REST::Dispatch::' . $controller . '->_init_get';
        my $retval = eval $exp;
        $log->debug( "Initialized GET sub-controllers by executing $exp with return value $retval" );
    }
}


sub _init_post {
   
    my $router_post = __PACKAGE__->SUPER::_router_post( Path::Router->new );
    die "Bad router" unless $router_post->isa( 'Path::Router' );

    $router_post->add_route( '',
        ( target => \&_post_default, )
    );

    foreach my $controller ( @{ $site->DISPATCH_CONTROLLERS } ) {
        my $exp = 'App::Dochazka::REST::Dispatch::' . $controller . '->_init_post';
        my $retval = eval $exp;
        $log->debug( "Initialized POST sub-controllers by executing $exp with return value $retval" );
    }
}



=head1 ACTION FUNCTIONS

The following functions implement actions for the various controllers.

=cut


sub _get_default {
    my ( %ARGS ) = @_;

    my $uri = $ARGS{'context'}->{'uri'};
    $uri =~ s/\/*$//;
    my $server_status = App::Dochazka::REST::dbh::status;
    my $status = $CELL->status_ok( 
        'DISPATCH_DEFAULT', 
        args => [ $VERSION, $server_status ],
        payload => { 
            documentation => $site->DOCHAZKA_DOCUMENTATION_URI,
            resources => {
                'employee' => {
                    link => "$uri/employee",
                    description => 'Employee (i.e. a user of Dochazka)',
                    acl_profile => 'passerby',
                },
                'privhistory' => {
                    link => "$uri/privhistory",
                    description => "Privilege history (changes to an employee's privilege level over time)",
                    acl_profile => 'passerby',
                },
#                'schedhistory' => {
#                    link => "$uri/schedhistory",
#                    description => "Schedule history (changes to an employee's schedule over time)",
#                },
#                'schedule' => {
#                    link => "$uri/schedule",
#                    description => "Schedule (expected weekly work hours of an employee or employees)",
#                },
#                'activity' => {
#                    link => "$uri/activity",
#                    description => "Activity (a way in which employees can spend their time)",
#                },
#                'interval' => {
#                    link => "$uri/interval",
#                    description => "Interval (a period of time during which an employee did something)",
#                },
#                'lock' => {
#                    link => "$uri/lock",
#                    description => "Lock (a period of time over which it is not possible to create, update, or delete intervals)",
#                },
                'siteparam/:param' => {
                    link => "$uri/siteparam/:param",
                    description => "Site parameter (a value configurable by the site administrator)",
                    acl_profile => 'admin',
                },
            },
        },
    );
    return $status;
}


sub _get_site_param {
    my ( %ARGS ) = @_;

    # generate content
    my ( $param, $value, $status );
    $param = $ARGS{'context'}->{'mapping'}->{'param'};
    {
        no strict 'refs';
        $value = $site->$param;
    }
    $status = $value
        ? $CELL->status_ok( 
              'DISPATCH_SITE_PARAM_FOUND', 
              args => [ $param ], 
              payload => { $param => $value } 
          )
        : $CELL->status_err( 
              'DISPATCH_SITE_NOT_DEFINED', 
              args => [ $param ] 
          );
    return $status;
}


sub _get_forbidden { die "Das ist streng verboten"; }

1;
