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
# Lock dispatcher/controller module
# ------------------------

package App::Dochazka::REST::Dispatch::Lock;

use strict;
use warnings;

use App::CELL qw( $CELL $log $site );
use App::Dochazka::REST::Dispatch::ACL qw( check_acl_context );
#use App::Dochazka::REST::Dispatch::Shared qw( not_implemented pre_update_comparison );
use App::Dochazka::REST::Model::Lock;
use App::Dochazka::REST::Model::Shared;
use Data::Dumper;
use Params::Validate qw( :all );



=head1 NAME

App::Dochazka::REST::Dispatch::Lock - path dispatch





=head1 VERSION

Version 0.352

=cut

our $VERSION = '0.352';




=head1 DESCRIPTION

Controller/dispatcher module for the 'Lock' resource. To determine
which functions in this module correspond to which resources, see.






=head1 RESOURCES

This section documents the resources whose dispatch targets are contained
in this source module - i.e., lock resources. For the resource
definitions, see C<config/dispatch/lock_Config.pm>.

Each resource can have up to four targets (one each for the four supported
HTTP methods GET, POST, PUT, and DELETE). That said, target routines may be
written to handle more than one HTTP method and/or more than one resoure.

=cut


# runtime generation of four routines: _get_default, _post_default,
# _put_default, _delete_default (top-level resource targets)
BEGIN {
    no strict 'refs';
    *{"_get_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_LOCK', http_method => 'GET' );
    *{"_post_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_LOCK', http_method => 'POST' );
    *{"_put_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_LOCK', http_method => 'PUT' );
    *{"_delete_default"} =
        App::Dochazka::REST::Dispatch::Shared::make_default( resource_list => 'DISPATCH_RESOURCES_LOCK', http_method => 'DELETE' );
}


# 'lock/new'
sub _new {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__. "::_new" ); 

    my $conn = $context->{'dbix_conn'};

    # make sure request body with all required fields is present
    return $CELL->status_err('DOCHAZKA_MALFORMED_400') unless $context->{'request_body'};
    foreach my $missing_prop ( qw( intvl ) ) {
        if ( not exists $context->{'request_body'}->{$missing_prop} ) {
            return $CELL->status_err( 'DISPATCH_PARAMETER_BAD_OR_MISSING', args => [ $missing_prop ] );
        }
    }

    # this resource requires special ACL handling; check_acl_context also adds
    # the 'eid' property if it is missing
    my $status = check_acl_context( $context );
    return $status if $status->not_ok;

    # attempt to insert
    return _insert_lock( $context );
}

# takes PROPLIST
sub _insert_lock {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug("Reached " . __PACKAGE__ . "::_insert_lock" );

    my %proplist_before = %{ $context->{'request_body'} };
    $log->debug( "Properties before filter: " . join( ' ', keys %proplist_before ) );
        
    # spawn an object, filtering the properties first
    my @filtered_args = App::Dochazka::Model::Lock::filter( %proplist_before );
    my %proplist_after = @filtered_args;
    $log->debug( "Properties after filter: " . join( ' ', keys %proplist_after ) );
    my $int = App::Dochazka::REST::Model::Lock->spawn( @filtered_args );

    # execute the INSERT db operation
    return $int->insert( $context );
}

1;
