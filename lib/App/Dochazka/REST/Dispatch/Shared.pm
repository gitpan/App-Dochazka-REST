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
# Shared dispatch functions
# ------------------------

package App::Dochazka::REST::Dispatch::Shared;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use Data::Dumper;
use Params::Validate qw( :all );



=head1 NAME

App::Dochazka::REST::Dispatch::Shared - Shared dispatch functions





=head1 VERSION

Version 0.207

=cut

our $VERSION = '0.207';





=head1 DESCRIPTION

This module provides code that is shared within the various dispatch modules.

=cut




=head1 FUNCTIONS


=head2 make_default

Every top-level resource has a '_get_default' target. Here is the code for that.

=cut

sub make_default {
    my %ARGS = validate( @_, { 
            resource_list => { type => SCALAR }, 
            http_method => { regex => qr/^(GET)|(HEAD)|(PUT)|(POST)|(DELETE)$/ } 
        }
    );
    return sub {
        my ( $context ) = validate_pos( @_, { type => HASHREF } );

        my $resource_defs = $site->get_param( $ARGS{resource_list} );
        my @rlist = keys %$resource_defs;
        $log->debug( 'make_default: processing ' . scalar @rlist . ' resources for ' . $ARGS{http_method} . ' request' );
        my $server_status = App::Dochazka::REST::dbh::status();
        my $uri = $context->{'uri'};
        $uri =~ s/\/*$//;
        my $acl_priv = $context->{'acl_priv'};
        my $acls;
        $acls = { 'passerby' => '', 'inactive' => '', 'active' => '', 'admin' => '', } if $acl_priv eq 'admin';
        $acls = { 'passerby' => '', 'inactive' => '', 'active' => '', } if $acl_priv eq 'active';
        $acls = { 'passerby' => '', 'inactive' => '', } if $acl_priv eq 'inactive';
        $acls = { 'passerby' => '', } if $acl_priv eq 'passerby';
        my $method = $context->{'method'};

        # populate resources
        my $resources = {};
        $log->debug( "Resource List: " . Dumper( \@rlist ) );
        foreach my $entry ( @rlist ) {
            # include resource in help list only if current employee is authorized to access it
            # _AND_ the method is allowed
            my $rspec = $resource_defs->{ $entry };
            if ( defined( $rspec->{'acl_profile'} ) and exists( $acls->{ $rspec->{'acl_profile'} } )
                 and grep { $_ eq $method; } keys( %{ $rspec->{'target'} } ) ) {
                $resources->{ $entry } = {
                    link => "$uri/$entry",
                    description => $rspec->{'description'},
                    acl_profile => $rspec->{'acl_profile'},
                };
            }
        }

        my $status = $CELL->status_ok( 
            'DISPATCH_DEFAULT', 
            args => [ $VERSION, $server_status ],
            payload => { 
                documentation => $site->DOCHAZKA_DOCUMENTATION_URI,
                method => $context->{'method'},
                resources => $resources,
            },
        );
        $log->debug("Dispatch/Shared.pm->make_default is finished, returning " . $status->code . " status" );
        return $status;
    };
}


1;
