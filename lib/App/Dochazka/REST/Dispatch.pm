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
use App::Dochazka::REST::Model::Employee;
use Carp;
use Data::Dumper;
use Scalar::Util qw( blessed );

use parent 'App::Dochazka::REST::dbh';

=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.099

=cut

our $VERSION = '0.099';





=head1 DESCRIPTION

This module contains a single function, L<is_auth>, that processes the "path"
from the HTTP request. 

=cut


=head2 is_auth

Takes a PARAMHASH with the following mandatory parameters: 

    'eid'     the EID of the employee making the request
    'priv'    current privilege level of that employee
    'method'  the HTTP method being used to access the resource
    'path'    the path string

Returns a status object, the level of which can be either 'OK' (authorized) or
'NOT_OK' (not authorized). If the status is 'OK', the payload will contain a
reference to a hash that will look like this:

    {
        rout => CODEREF,
        args => [ ... ],
    }

where 'rout' is a reference to the subroutine to be run to obtain the JSON
string to be placed in the HTTP response, and 'args' is a list of arguments to
be provided to that function. Also, the extraneous URL part (if any) is
appended to the status object as 'extra'.

=cut

sub is_auth {
    my ( @ARGS ) = @_;
    croak "Odd number of arguments" if @ARGS % 2;
    my %ARGS = @ARGS;

    my $status; # allocate memory for response
    my $extra;

    # split the path into tokens
    # FIXME: implement escaping of '/' characters so tokens can contain them
    my $path = $ARGS{path};
    $path =~ s/^\///;
    my @tokens = split( /\//, $path );


    # $token[0] specifies the resource
    $tokens[0] = 'default' if ! @tokens or $tokens[0] =~ m/help/i or $tokens[0] =~ m/version/i;
    my $resource = shift @tokens;

    if ( $resource =~ m/default/i ) {
        $status = $CELL->status_ok( 'DOCHAZKA_AUTH_OK', 
            payload => {
                rout => \&_default,
                args => [ @tokens ],
            }
        );
    }
    elsif ( $resource =~ m/site/i ) {
        $status = $CELL->status_ok( 'DOCHAZKA_AUTH_OK', 
            payload => {
                rout => \&_site,
                args => [ @tokens ]
            }
        );
    }
    elsif ( $resource =~ m/forbidden/i ) {
        $status = $CELL->status_not_ok;
    }

    # resource not recognized
    return $CELL->status_ok( 'DOCHAZKA_AUTH_OK', 
        payload => {
            rout => \&_bad_resource,
            args => [ @tokens ]
        }
    ) if ! defined $status;

    return $status;
}


sub _default {
    my @tokens = @_;
    my $server_status = __PACKAGE__->SUPER::status;
    my $uri = $site->DOCHAZKA_URI;
    my $status = $CELL->status_ok( 
        'DISPATCH_DEFAULT', 
        args => [ $VERSION, $server_status ],
        payload => { 
            documentation => $site->DOCHAZKA_DOCUMENTATION_URI,
            resources => {
                'employee' => {
                    link => "$uri/employee",
                    description => 'Employee (i.e. a user of Dochazka)',
                },
                'privhistory' => {
                    link => "$uri/privhistory",
                    description => "Privilege history (changes to an employee's privilege level over time)",
                },
                'schedhistory' => {
                    link => "$uri/schedhistory",
                    description => "Schedule history (changes to an employee's schedule over time)",
                },
                'schedule' => {
                    link => "$uri/schedule",
                    description => "Schedule (expected weekly work hours of an employee or employees)",
                },
                'activity' => {
                    link => "$uri/activity",
                    description => "Activity (a way in which employees can spend their time)",
                },
                'interval' => {
                    link => "$uri/interval",
                    description => "Interval (a period of time during which an employee did something)",
                },
                'lock' => {
                    link => "$uri/lock",
                    description => "Lock (a period of time over which it is not possible to create, update, or delete intervals)",
                },
                'siteparam' => {
                    link => "$uri/siteparam",
                    description => "Site parameter (a value configurable by the site administrator)",
                },
            },
        },
    );
    $status->{'extra_tokens'} = \@tokens if @tokens;
    return $status;
}


sub _site {
    no strict 'refs';
    my @tokens = @_;
    my ( $param, $value, $status );
    $param = shift @tokens;

    $log->info( "Entering _site, \$param is undefined" ) if ! defined $param;
    $log->info( "Entering _site, \$param is $param" ) if defined $param;

    # correct value for $path looks like, e.g. '/DOCHAZKA_APPNAME'
    if ( $param ) {
        $value = $site->$param;
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
    } else {
        $status = $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', 
            args => [ "site param" ] );
    }
    $status->{'extra_tokens'} = \@tokens if @tokens;
    return $status;
}
    

# FIXME
sub _emp_by_nick {
    my ( $path ) = @_;     # sk means Search Key
    my ( $sk, $status );

    $log->info( "Entering _emp_by_nick with path ->$path<-" );
    # correct value for $path looks like '/[SEARCH_KEY]'
    if ( $path =~ s/^\/([^\/]+)// ) {
        $sk = $1;
        $log->info( "Search key is ->$sk<-" );
        $status = App::Dochazka::REST::Model::Employee->select_multiple_by_nick( 
            __PACKAGE__->SUPER::dbh, $sk );
    } else {
        $status = $CELL->status_err( 'DISPATCH_MISSING_PARAMETER', 
            args => [ "search key" ] );
    }
    #$status->{'extra_tokens'} = \@tokens if @tokens;
    return $status;
}


# FIXME: should be DISPATCH_BAD_RESOURCE
sub _bad_resource {
    my @tokens = @_;

    return $CELL->status_err( 
        'DISPATCH_UNRECOGNIZED', 
        payload => { 
            request => join( '/', @tokens ),
        },
    );
}


sub _forbidden {
    my @tokens = @_;

    return $CELL->status_err( 
        'DISPATCH_FORBIDDEN', 
        payload => { 
            request => join( '/', @tokens ),
        },
    );
}

1;
