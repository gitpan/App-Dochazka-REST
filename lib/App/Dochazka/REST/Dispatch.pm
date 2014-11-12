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
use App::Dochazka::REST::Dispatch::Priv;
use App::Dochazka::REST::Dispatch::Shared qw( not_implemented );
use App::Dochazka::REST::Util qw( pod_to_html );
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

Version 0.271

=cut

our $VERSION = '0.271';




=head1 DESCRIPTION

This is the top-level dispatch module: i.e., it contains dispatch targets
for the top-level resources defined in
C<config/dispatch/dispatch_Top_Config.pm>.




=head1 RESOURCE TARGETS

This section documents the resource targets whose source code resides in
this module.

=cut

# the following BEGIN block generates the _get_default, _post_default,
# _put_default, and delete_default subroutines (targets) at runtime
BEGIN {
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


sub _docu {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my $resource = $context->{'request_body'} || "";
    my $acl_profile = $meta->META_DOCHAZKA_RESOURCE_ACLS->{$resource} || '!?NONE?!';
    my $docs = $meta->META_DOCHAZKA_RESOURCE_DOCS->{$resource} || 'NONE WRITTEN YET';
    #chomp($docs);
    #$docs =~ s/\R/ /g;
    if ( exists $meta->META_DOCHAZKA_RESOURCE_DOCS->{$resource} ) {
        return $CELL->status_ok( 'DISPATCH_ONLINE_DOCUMENTATION',
            payload => {
               'resource' => ( defined $resource )
                   ? $resource
                   : "",
               'acl_profile' => $acl_profile,
               'documentation_format' => 'POD',
               'documentation' => $docs,
            },
        );
    } else {
        return $CELL->status_err( 'DISPATCH_BAD_RESOURCE' );
    }
}


sub _docu_html {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    my $resource = $context->{'request_body'} || "";
    my $acl_profile = $meta->META_DOCHAZKA_RESOURCE_ACLS->{$resource} || '!?NONE?!';
    my $docs = $meta->META_DOCHAZKA_RESOURCE_DOCS->{$resource} || 'NONE WRITTEN YET';
    #chomp($docs);
    #$docs =~ s/\R/ /g;
    if ( exists $meta->META_DOCHAZKA_RESOURCE_DOCS->{$resource} ) {
        return $CELL->status_ok( 'DISPATCH_ONLINE_DOCUMENTATION',
            payload => {
               'resource' => ( defined $resource )
                   ? $resource
                   : "",
               'acl_profile' => $acl_profile,
               'documentation_format' => 'HTML',
               'documentation' => pod_to_html( $docs ),
            },
        );
    } else {
        return $CELL->status_err( 'DISPATCH_BAD_RESOURCE' );
    }
}


sub _forbidden { 
    die <<'EOH';
This message should never be displayed, because the lack of an acl_profile
property in the resource definition should be enough to guarantee that all
requests get resolved to 405 Method Not Allowed
EOH
}



sub _get_param {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    # generate content
    my ( $param, $path, $value, $status, $type );
    $param = $context->{'mapping'}->{'param'};
    $path = $context->{'path'};
    if ( $path =~ m/siteparam/ ) {
        $type = 'site';
        $value = $site->get_param_metadata( $param ), 
    } elsif ( $path =~ m/metaparam/ ) {
        $type = 'meta';
        $value = $meta->get_param_metadata( $param );
    }
    $status = defined( $value )
        ? $CELL->status_ok( 
              'DISPATCH_PARAM_FOUND', 
              args => [ $type, $param ], 
              payload => { 
                  type => $type,
                  name => $param,
                  value => $value->{'Value'},
                  where_defined => {
                      file => $value->{'File'},
                      line => $value->{'Line'},
                  }
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
    my ( $param, $path, $status, $type );
    $param = $context->{'mapping'}->{'param'};
    $path = $context->{'path'};
    my ( $method, $body ) = ( $context->{'method'}, $context->{'request_body'} );
    $log->debug( __PACKAGE__ . "::_put_param: request body is " . Dumper( $body ) );
    $log->debug( __PACKAGE__ . "::_put_param: about to set metaparam $param to " . Dumper( $body ) );
    if ( $path =~ m/metaparam/ ) {
        $type = 'meta';
        $meta->set( $param, $body );
    }
    $status = ( eq_deeply( $meta->get_param( $param ), $body ) )
        ? $CELL->status_ok( 
              'DISPATCH_PARAM_SET', 
              args => [ $type, $param ], 
              payload => { 
                  type => $type,
                  name => $param,
                  value => $body,
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


sub _get_version {
    return $CELL->status_ok( 'DISPATCH_DOCHAZKA_REST_VERSION', 
        payload => { version => $VERSION } );
}

1;
