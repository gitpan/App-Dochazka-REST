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
use App::Dochazka::REST::Model::Shared qw( priv_by_eid schedule_by_eid );
use Data::Dumper;
use Params::Validate qw( :all );



=head1 NAME

App::Dochazka::REST::Dispatch::Shared - Shared dispatch functions





=head1 VERSION

Version 0.263

=cut

our $VERSION = '0.263';





=head1 DESCRIPTION

This module provides code that is shared within the various dispatch modules.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( not_implemented pre_update_comparison );




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


=head2 not_implemented

A generic function for handling resources that aren't implemented yet.

=cut

sub not_implemented {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug("Entering _not_implemented, path is " . $context->{path} );
    return $CELL->status_notice( 
        'DISPATCH_RESOURCE_NOT_IMPLEMENTED',
        payload => { 
            "resource" => $context->{'path'},
            "method" => $context->{'method'},
        },
    );
}


=head2 pre_update_comparison

Given an original object and a hashref of possible changed properties,
compare the properties in the hashref with the corresponding properties 
in the original object. If any properties really are changed, update
the object. Return the number of properties so changed.

=cut

sub pre_update_comparison {
    my ( $obj, $over ) = @_;
    my $c = 0;
    foreach my $prop (keys %$over) {
        if ( exists $obj->{$prop} ) {
            next if not defined $obj->{$prop} and not defined $over->{$prop};
            next if ( defined $obj->{$prop} and defined $over->{$prop} ) and ( $obj->{$prop} eq $over->{$prop} );
            if (
                 ( defined $obj->{$prop} and not defined $over->{$prop} ) or
                 ( not defined $obj->{$prop} and defined $over->{$prop} ) or
                 ( $obj->{$prop} ne $over->{$prop} ) 
               ) {
                $obj->{$prop} = $over->{$prop};
                $c += 1;
            }
        }
    }
    return $c;
}


=head2 current

Generalized routine for the following resources:

    /priv/current/?:ts
    /schedule/current/?:ts
    /priv/eid/:eid/?:ts
    /schedule/eid/:eid/?:ts
    /priv/nick/:nick/?:ts
    /schedule/nick/:nick/?:ts
    
Takes a SCALAR that can be either 'priv' or 'schedule', plus a HASHREF that
should contain the request context from Resource.pm

=cut

sub current {
    my ( $t, $context ) = validate_pos( @_, 
        { type => SCALAR },
        { type => HASHREF } 
    );

    $log->debug( "Entering " . __PACKAGE__ . "::current with $t" );

    my $ts = $context->{'mapping'}->{'ts'};
    my $eid = $context->{'mapping'}->{'eid'};
    my $nick = $context->{'mapping'}->{'nick'};
    my $resource;
    my $status;

    # determine which resource was requested
    if ( not $eid and not $nick ) {
        $resource = "$t/current/?:ts";
        $eid = $context->{'current'}->{'eid'};
    } elsif ( $eid and not $nick ) {
        $resource = "$t/current/eid/:eid/?:ts";
    } elsif ( $nick and not $eid ) {
        $resource = "$t/current/nick/:nick/?:ts";
    } else {
        die "AAAAAAAAAAAAHHHHHHH! Swallowed by the abyss";
    }

    # we have one of {EID,nick} but we need both
    if ( $nick ) {
        # "$t/current/nick/:nick/?:ts" resource
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        $eid = ( ref( $status->payload) eq 'App::Dochazka::REST::Model::Employee' )
            ? $status->payload->{'eid'}
            : undef;
        return $CELL->status_err('DISPATCH_NICK_DOES_NOT_EXIST', args => [ $nick ]) unless $eid;
    } else {
        # "$t/current/?:ts" resource
        # "$t/current/eid/:eid/?:ts" resource
        $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
        $nick = ( ref( $status->payload) eq 'App::Dochazka::REST::Model::Employee' )
            ? $status->payload->{'nick'}
            : undef;
        return $CELL->status_err('DISPATCH_EID_DOES_NOT_EXIST', args => [ $eid ]) unless $nick;
    }

    # employee exists and we have her EID and nick: get privlevel
    if ( $t eq 'priv' ) {
        $status = priv_by_eid( $eid, $ts );
        # on success, $status will be a SCALAR like 'inactive'
        if ( not ref($status) ) {
            if ( $ts ) {
                return $CELL->status_ok(
                    'DISPATCH_EMPLOYEE_PRIV_AS_AT', 
                    args => [ $ts, $nick, $status ],
                    payload => { 
                        eid => $eid += 0,  # "numify"
                        nick => $nick,
                        priv => $status,
                        timestamp => $ts,
                    }, 
                );
            } else {
                return $CELL->status_ok(
                    'DISPATCH_EMPLOYEE_PRIV', 
                    args => [ $nick, $status ],
                    payload => { 
                        eid => $eid += 0,  # "numify"
                        nick => $nick,
                        priv => $status,
                    }, 
                );
            }
        }
    } elsif ( $t eq 'schedule' ) {
        $status = schedule_by_eid( $eid, $ts );
        # on success, $status will be a HASHREF like {}
        if ( ref($status) eq 'HASH' ) {
            if ( $ts ) {
                return $CELL->status_ok(
                    'DISPATCH_EMPLOYEE_SCHEDULE_AS_AT', 
                    args => [ $nick, $ts ],
                    payload => { 
                        eid => $eid += 0,
                        nick => $nick,
                        schedule => $status,
                        timestamp => $ts,
                    }, 
                );
            } else {
                return $CELL->status_ok(
                    'DISPATCH_EMPLOYEE_SCHEDULE', 
                    args => [ $nick ],
                    payload => { 
                        eid => $eid += 0,
                        nick => $nick,
                        schedule => $status,
                    }, 
                );
            }
        }
    }
    return $status;
}


1;
