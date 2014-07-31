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
use App::Dochazka::REST::Model::Employee qw( noof_employees_by_priv );
use App::Dochazka::REST::Model::Shared qw( noof );
use Carp;
use Data::Dumper;
use Path::Router;
use Scalar::Util qw( blessed );

use parent 'App::Dochazka::REST::Dispatch';




=head1 NAME

App::Dochazka::REST::Dispatch::Employee - path dispatch





=head1 VERSION

Version 0.125

=cut

our $VERSION = '0.125';




=head1 DESCRIPTION

Controller/dispatcher module for the 'employee' resource.






=head1 FUNCTIONS

=head2 _init_get

Adds employee-related routes to C<$router_get> (router for GET requests).

=cut

sub _init_get {

    my $router_get = __PACKAGE__->SUPER::router( 'GET' );
    die "Bad Path::Router object" unless $router_get->isa( 'Path::Router' );

    $router_get->add_route( 'employee',
        defaults => {
            'acl_profile' => 'passerby',
        },
        target => \&_get_default,
    );

    $router_get->add_route( 'employee/help',
        defaults => {
            'acl_profile' => 'passerby',
        },
        target => \&_get_default,
    );

    $router_get->add_route( 'employee/nick/:param',
        defaults => {
            'acl_profile' => 'admin',
        },
        target => \&_get_nick,
    );

    $router_get->add_route( 'employee/eid/:param',
        defaults => {
            'acl_profile' => 'admin',
        },
        target => \&_get_eid,
    );

    $router_get->add_route( 'employee/current',
        defaults => {
            'acl_profile' => 'passerby',
        },
        target => \&_get_current,
    );

    $router_get->add_route( 'employee/logged_in',
        defaults => {
            'acl_profile' => 'passerby',
        },
        target => \&_get_current,
    );

    $router_get->add_route( 'whoami',
        defaults => {
            'acl_profile' => 'passerby',
        },
        target => \&_get_current,
    );

    $router_get->add_route( 'employee/count',
        defaults => {
            'acl_profile' => 'admin',
        },
        target => \&_get_count,
    );

    $router_get->add_route( 'employee/count/:priv',
        defaults => {
            'acl_profile' => 'admin',
        },
        target => \&_get_count_priv,
    );

    return "Employee GET router initialization complete";   
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

    my $uri = $ARGS{'context'}->{'uri'};
    $uri =~ s/\/*$//;
    my $server_status = App::Dochazka::REST::dbh::status;
    return $CELL->status_ok(
        'DISPATCH_EMPLOYEE_DEFAULT',
        args => [ $VERSION, $server_status ],
        payload => {
            documentation => $site->DOCHAZKA_DOCUMENTATION_URI,
            resources => {
                'nick/:param' => {
                    link => "$uri/employee/nick/:param",
                    description => 'Search for employees by nick (either exact match or LIKE match using %)',
                    acl_profile => 'admin',
                },
                'eid/:param' => {
                    link => "$uri/employee/eid/:param",
                    description => "Load a single employee by EID",
                    acl_profile => 'admin',
                },
                'current' => {
                    link => "$uri/employee/current",
                    description => "Display profile of current employee (i.e., the employee you logged in as)",
                    acl_profile => 'passerby',
                },
                'count' => {
                    link => "$uri/employee/count",
                    description => "Display total count of employees of all privilege levels",
                    acl_profile => 'admin',
                },
                'count/:priv' => {
                    link => "$uri/employee/count/:priv",
                    description => "Display total count of employees of a particular privilege level ('admin', 'active', 'inactive', or 'passerby')",
                    acl_profile => 'admin',
                },
            },
        },
    );
}


sub _get_nick {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_nick" ); 

    my $nick = $ARGS{'context'}->{'mapping'}->{'param'};
    my $status = App::Dochazka::REST::Model::Employee->
        select_multiple_by_nick( $nick );
    if ( $status->payload ) {
        foreach my $emp ( @{ $status->payload } ) {
            $emp = $emp->expurgate;
        }
        my $count = @{ $status->payload };
        $status->payload( $status->{'payload'}->[0] ) if $count == 1;
    }
    return $status;
}


sub _get_eid {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_eid" ); 

    my $eid = $ARGS{'context'}->{'mapping'}->{'param'};
    App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
}


sub _get_current {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_current" ); 

    my $current_emp = $ARGS{'context'}->{'current'};
    $CELL->status_ok( 'DISPATCH_EMPLOYEE_CURRENT', args => 
        [ $current_emp->{'nick'} ], payload => $current_emp );
}


sub _get_count {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_count" ); 

    my $result = noof_employees_by_priv( 'total' );
    return $result;
}


sub _get_count_priv {
    my ( %ARGS ) = @_;
    $log->debug( "Entering App::Dochazka::REST::Dispatch::_get_count" ); 

    my $priv = $ARGS{'context'}->{'mapping'}->{'priv'};
    my $result = noof_employees_by_priv( $priv );
    return $result;
}

1;
