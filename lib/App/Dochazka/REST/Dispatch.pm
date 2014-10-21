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

use App::CELL qw( $CELL $log $site $meta );
use App::Dochazka::REST::dbh;
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Dispatch::Employee;
use App::Dochazka::REST::Dispatch::Privhistory;
use Carp;
use Data::Dumper;
#use JSON qw();
use Params::Validate qw( :all );
#use Scalar::Util qw( blessed );
use Test::Deep::NoTest;

#use parent 'App::Dochazka::REST::Resource';




=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.195

=cut

our $VERSION = '0.195';




=head1 DESCRIPTION

This is the top-level dispatch module: i.e., it contains dispatch targets
for the top-level resources defined in
C<config/dispatch/dispatch_Top_Config.pm>.




=head1 RESOURCES

This section documents the resources whose dispatch targets are contained
in this source module. For the resource definitions, see
C<config/dispatch/dispatch_Top_Config.pm>.

Each resource can have up to four targets (one each for the four supported
HTTP methods GET, POST, PUT, and DELETE). That said, target routines may be
written to handle more than one HTTP method and/or more than one resoure.


=head2 C<""> or C</>

B<Works with:> GET, POST, PUT, DELETE

This is the toppest of the top-level targets or, if you wish, the "root
target". If the base UID of your L<App::Dochazka::REST> instance is
C<http://dochazka.site:5000> and your username/password are "demo/demo",
then this resource is triggered by either of the URLs:

    http://demo:demo@dochazka.site:5000
    http://demo:demo@dochazka.site:5000/

In terms of behavior, this resource is identical to C<help> (see below).


=head2 C<help>

B<Works with:> GET, POST, PUT, DELETE

If the base UID of your L<App::Dochazka::REST> instance is
C<http://dochazka.site:5000> and your username/password are "demo/demo",
then this resource is triggered by either of the URLs:

    http://demo:demo@dochazka.site:5000/help
    http://demo:demo@dochazka.site:5000/help/
    
(This information applies analogously to all the resources described
herein.)

The purpose of the C<help> resource is to give the user an overview of all
the top-level resources available to her, with regard to her privlevel and
the HTTP method being used.

That means, for example:

=over

=item * If the HTTP method is GET, only resources with GET targets will be
displayed (same applies to other HTTP methods)

=item * If the user's privlevel is 'inactive', only resources whose ACL
profile is 'inactive' or lower (i.e., 'inactive' or 'passerby') will be
displayed

=back

The information provided is sent as a JSON string in the HTTP response
body, and includes the resource's name, full URI, ACL profile, and brief
description, as well as a link to the L<App::Dochazka::REST> on-line
documentation.


=head2 C<bugreport>

B<Works with:> GET

Returns a C<report_bugs_to> key in the payload, containing the address to
report bugs to.


=head2 C<echo>

B<Works with:> POST, PUT, DELETE

This resource simply takes whatever content body was sent and echoes it
back in the response body.


=head2 C<version>

B<Works with:> GET

Returns a C<version> key in the payload, containing the version number of
the running L<App::Dochazka::REST> instance.


=head2 C<siteparam/:param>

B<Works with:> GET

Assuming that the argument C<:param> is the name of an existing site
parameter, displays the parameter's value. This resource is available only
to users with C<admin> privileges.


=head2 C<metaparam/:param>

B<Works with:> GET, PUT

Assuming that the argument C<:param> is the name of an existing meta
parameter, displays the parameter's value. This resource is available only
to users with C<admin> privileges.





=head1 TARGETS

=cut

BEGIN {
    # generate four subroutines: _get_default, _post_default, _put_default,
    # delete_default
    no strict 'refs';
    *{"_get_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_TOP', http_method => 'GET' );
    *{"_post_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_TOP', http_method => 'POST' );
    *{"_put_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_TOP', http_method => 'PUT' );
    *{"_delete_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_TOP', http_method => 'DELETE' );
}


sub _get_param {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    # generate content
    my ( $param, $path, $value, $status, $type );
    $param = $context->{'mapping'}->{'param'};
    $path = $context->{'path'};
    if ( $path =~ m/siteparam/ ) {
        $type = 'site';
        $value = $site->get_param( $param ), 
    } elsif ( $path =~ m/metaparam/ ) {
        $type = 'meta';
        $value = $meta->get_param( $param );
    }
    $status = defined( $value )
        ? $CELL->status_ok( 
              'DISPATCH_PARAM_FOUND', 
              args => [ $type, $param ], 
              payload => { 
                  type => $type,
                  name => $param,
                  value => $value,
              } 
          )
        : $CELL->status_err( 
              'DISPATCH_PARAM_NOT_DEFINED', 
              args => [ $type, $param ] 
          );
    return $status;
}

# PUT is only for meta parameters
sub _put_param {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my ( $param, $path, $value, $status, $type );
    $param = $context->{'mapping'}->{'param'};
    $path = $context->{'path'};
    my ( $method, $body ) = ( $context->{'method'}, $context->{'request_body'} );
    $value = $body->{'value'};
    $log->debug("_put_param: about to set metaparam $param to " . Dumper( $value ) );
    if ( $path =~ m/metaparam/ ) {
        $type = 'meta';
        $meta->set( $param, $value );
    }
    $status = ( eq_deeply( $meta->get_param( $param ), $value ) )
        ? $CELL->status_ok( 
              'DISPATCH_PARAM_SET', 
              args => [ $type, $param ], 
              payload => { 
                  type => $type,
                  name => $param,
                  value => $value,
              } 
          )
        : $CELL->status_err( 
              'DISPATCH_PARAM_NOT_SET', 
              args => [ $type, $param ],
              payload => {
                  type => $type,
                  name => $param,
                  value => $meta->get_param( $param ),
              }
          );
    return $status;
}

sub _get_session {

    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    return $CELL->status_ok( 'DISPATCH_SESSION_DATA', payload => {
        session_id => $context->{'session_id'},
        session => $context->{'session'},
    } );
}

sub _get_bugreport {
    return $CELL->status_ok( 'DISPATCH_BUGREPORT', payload => {
        report_bugs_to => $site->DOCHAZKA_REPORT_BUGS_TO
    } );
}

sub _echo {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my ( $method, $body ) = ( $context->{'method'}, $context->{'request_body'} );

    # return a suitable payload, even if the request body is empty
    return $CELL->status_ok( 'DISPATCH_' . $method . '_ECHO', 
        payload => ( not defined $body or $body eq '' )
            ? undef
            : $body
    );
}


sub _forbidden { die "Das ist streng verboten"; }


sub _get_version {
    return $CELL->status_ok( 'DISPATCH_DOCHAZKA_REST_VERSION', 
        payload => { version => $VERSION } );
}

1;
