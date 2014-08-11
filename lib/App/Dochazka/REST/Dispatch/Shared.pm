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

Version 0.153

=cut

our $VERSION = '0.153';





=head1 DESCRIPTION

This module provides code that is shared within the various dispatch modules.

=cut




=head1 FUNCTIONS


=head2 make_default

Every top-level resource has a '_get_default' target. Here is the code for that.

=cut

sub make_default {
    no strict 'refs';
    my ( $site_param ) = validate_pos( @_, { type => SCALAR } );
    return sub {
        my ( $context ) = validate_pos( @_, { type => HASHREF } );

        # initialize local variables that we will need
        my $resource_defs_spec = 'DISPATCH_RESOURCES_' . uc $context->{'method'};
        my $resource_defs = $site->$resource_defs_spec;
        
        my $prlist = $site->$site_param; # 'prlist' is "Permitted Resources List"
        $log->debug( "Permitted resource list from \$site->$site_param" );
        my $server_status = App::Dochazka::REST::dbh::status;
        my $uri = $context->{'uri'};
        $uri =~ s/\/*$//;
        my $acl_priv = $context->{'acl_priv'};
        my $acls;
        $acls = { 'passerby' => '', 'inactive' => '', 'active' => '', 'admin' => '', } if $acl_priv eq 'admin';
        $acls = { 'passerby' => '', 'inactive' => '', 'active' => '', } if $acl_priv eq 'active';
        $acls = { 'passerby' => '', 'inactive' => '', } if $acl_priv eq 'inactive';
        $acls = { 'passerby' => '', } if $acl_priv eq 'passerby';

        # populate resources
        my $resources = {};
        $log->debug( "Permitted Resource List: " . Dumper( $prlist ) );
        foreach my $entry ( @$prlist ) {
            # include resource in help list only if current employee is authorized to access it
            my $rspec = $resource_defs->{ $entry };
            if ( defined $rspec->{'acl_profile'} and exists $acls->{ $rspec->{'acl_profile'} } ) {
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
        return $status;
    };
}


1;
