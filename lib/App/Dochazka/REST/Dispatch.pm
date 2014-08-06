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
use JSON;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );

use parent 'App::Dochazka::REST::Resource';




=head1 NAME

App::Dochazka::REST::Dispatch - path dispatch





=head1 VERSION

Version 0.144

=cut

our $VERSION = '0.144';




=head1 DESCRIPTION

This is the top-level controller module: i.e., it contains top-level dispatch targets.




=head1 TARGETS

=cut

BEGIN {
    no strict 'refs';
    *{"_get_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_TOPLEVEL_GET' );
    *{"_post_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_TOPLEVEL_POST' );
    *{"_put_default"} = 
        App::Dochazka::REST::Dispatch::Shared::make_default( 'DISPATCH_HELP_TOPLEVEL_PUT' );
}


sub _get_site_param {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    # generate content
    my ( $param, $value, $status );
    $param = $context->{'mapping'}->{'param'};
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


sub _post_echo {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    _process_echo( $context->{'method'}, $context->{'request_body'} );
}


sub _put_echo {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    _process_echo( $context->{'method'}, $context->{'request_body'} );
}


# carefully put the request body in the payload
sub _process_echo {
    my ( $method, $body ) = @_;

    # return a suitable payload, even if the request body is empty
    return $CELL->status_ok( 'DISPATCH_' . $method . '_ECHO', 
        payload => ( not defined $body or $body eq '' )
            ? undef
            : $body
    );
}

sub _get_forbidden { die "Das ist streng verboten"; }

sub _post_forbidden { die "Das ist streng verboten"; }

1;
