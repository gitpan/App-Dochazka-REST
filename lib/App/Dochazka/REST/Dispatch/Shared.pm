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
use App::Dochazka::REST::Dispatch::ACL qw( check_acl );
use App::Dochazka::REST::Model::Shared qw( priv_by_eid schedule_by_eid );
use Data::Dumper;
use Params::Validate qw( :all );
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Dispatch::Shared - Shared dispatch functions





=head1 VERSION

Version 0.300

=cut

our $VERSION = '0.300';





=head1 DESCRIPTION

This module provides code that is shared within the various dispatch modules.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( 
    not_implemented 
    pre_update_comparison 
);



=head1 PACKAGE VARIABLES

The package variable C<%f_dispatch> is used in C<fetch_by_eid>, C<fetch_by_nick>,
and C<fetch_own>.

=cut

my %f_dispatch = (
    "attendance" => \&App::Dochazka::REST::Model::Interval::fetch_by_eid_and_tsrange,
    "lock" => \&App::Dochazka::REST::Model::Lock::fetch_by_eid_and_tsrange,
);
my %id_dispatch = (
    "attendance" => "App::Dochazka::REST::Model::Interval",
    "lock" => "App::Dochazka::REST::Model::Lock",
);


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
        my $method = $context->{'method'};

        # determine the user's privlevel (stored in 'acl_priv' property of context)
        my $acl_priv = $context->{'acl_priv'};

        # populate resources
        my $resources = {};
        $log->debug( "Resource List: " . Dumper( \@rlist ) );
        foreach my $entry ( @rlist ) {
            # include resource in help list only if current employee is authorized to access it
            # _AND_ the method is allowed
            my $rspec = $resource_defs->{ $entry };
            my $acl_profile;
            if ( defined( $rspec->{'acl_profile'} ) ) {
                $acl_profile = ref( $rspec->{'acl_profile'} )
                    ? $rspec->{'acl_profile'}->{ $method }
                    : $rspec->{'acl_profile'};
                if ( defined( $acl_profile ) and check_acl( $acl_profile, $acl_priv ) and 
                     grep { $_ eq $method; } keys( %{ $rspec->{'target'} } ) ) {
                    $resources->{ $entry } = {
                        link => "$uri/$entry",
                        description => $rspec->{'description'},
                        acl_profile => $rspec->{'acl_profile'},
                    };
                }
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
#            next if ( defined $obj->{$prop} and defined $over->{$prop} ) and ( $obj->{$prop} eq $over->{$prop} );
#            if (
#                 ( defined $obj->{$prop} and not defined $over->{$prop} ) or
#                 ( not defined $obj->{$prop} and defined $over->{$prop} ) or
#                 ( $obj->{$prop} ne $over->{$prop} ) 
#               ) {
                $obj->{$prop} = $over->{$prop};
                $c += 1;
#            }
        }
    }
    return $c;
}


=head2 current

Generalized routine for the following resources:

    /priv/self/?:ts
    /schedule/self/?:ts
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
    my %dispatch = (
        'priv' => \&priv_by_eid,
        'schedule' => \&schedule_by_eid,
    );

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
        # "$t/nick/:nick/?:ts" resource
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
        $eid = ( ref( $status->payload) eq 'App::Dochazka::REST::Model::Employee' )
            ? $status->payload->{'eid'}
            : undef;
        return $CELL->status_err('DISPATCH_EMPLOYEE_DOES_NOT_EXIST', args => [ 'nick', $nick ]) unless $eid;
    } else {
        # "$t/self/?:ts" resource
        # "$t/eid/:eid/?:ts" resource
        $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
        $nick = ( ref( $status->payload) eq 'App::Dochazka::REST::Model::Employee' )
            ? $status->payload->{'nick'}
            : undef;
        return $CELL->status_err('DISPATCH_EMPLOYEE_DOES_NOT_EXIST', args => [ 'EID', $eid ]) unless $nick;
    }

    # employee exists and we have her EID and nick: get privlevel/schedule
    $status = $dispatch{$t}->( $eid, $ts );
    # on success, $status will be a SCALAR like 'inactive' (priv) or a long JSON string (schedule)
    if ( ref($status) ne 'App::CELL::Status' ) {
        my @privsched = ( $t, $status );
        if ( $ts ) {
            return $CELL->status_ok(
                'DISPATCH_EMPLOYEE_' . uc( $t ) . '_AS_AT',
                args => [ $ts, $nick, $status ],
                payload => { 
                    eid => $eid += 0,  # "numify"
                    nick => $nick,
                    timestamp => $ts,
                    @privsched,
                }, 
            );
        } else {
            return $CELL->status_ok(
                'DISPATCH_EMPLOYEE_' . uc( $t ),
                args => [ $nick, $status ],
                payload => { 
                    eid => $eid += 0,  # "numify"
                    nick => $nick,
                    @privsched,
                }, 
            );
        }
    }
    # something very strange and unexpected happened
    $status->level( 'CRIT' );
    return $status;
}


sub _prop_from_class {
    my ( $class ) = @_;
    my $prop;
    if ( $class =~ m/Privhistory$/ or $class =~ m/Priv$/ ) {
        $prop = 'priv';
    } elsif ( $class =~ m/Schedhistory$/ or $class =~ m/Schedule$/ ) {
        $prop = 'sid';
    } else {
        die "AAAAAAAAHAHAHHHH!";
    }
}

# generalized dispatch target for GET and POST requests on resources:
#     'priv/history/eid/:eid' 
#     'priv/history/eid/:eid/:tsrange' 
#     'schedule/history/eid/:eid' 
#     'schedule/history/eid/:eid/:tsrange' 
#     'priv/history/nick/:nick' 
#     'priv/history/nick/:nick/:tsrange' 
#     'schedule/history/nick/:nick' 
#     'schedule/history/nick/:nick/:tsrange' 
sub history {
    my %PH = validate( @_, {
        'class' => { type => SCALAR },       # e.g. 'App::Dochazka::REST::Dispatch::Priv'
        'method' => { type => SCALAR },      # e.g. 'GET'
        'key' => { type => ARRAYREF },       # e.g. [ 'EID', 35 ], [ 'nick', 'mrfoo' ]
        'tsrange' => { type => SCALAR|UNDEF, optional => 1 }, # e.g. '[ 1969-04-27 08:00, 1971-04-26 08:00 )'
        'body' => { type => HASHREF|UNDEF, optional => 1 },
    } );
    my $prop = _prop_from_class( $PH{class} );
    my ( $status );
    if ( lc( $PH{key}->[0] ) eq 'eid' ) {
        $status = App::Dochazka::REST::Model::Employee->load_by_eid( $PH{key}->[1] );
    } elsif ( lc( $PH{key}->[0] ) eq 'nick' ) {
        $status = App::Dochazka::REST::Model::Employee->load_by_nick( $PH{key}->[1] );
    } else {
        die "AHAAHHAAAAAAAAHAAAHHHH!";
    }
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $emp = $status->payload;
        if ( $PH{method} eq 'GET' ) {
            return _get_history( class => $PH{'class'}, eid => $emp->eid, 
                nick => $emp->nick, tsrange => $PH{'tsrange'} );
        } elsif ( $PH{method} eq 'POST' ) {
            return _put_history( class => $PH{'class'}, eid => $emp->eid, body => $PH{'body'} );
        } else {
            die "AAAAAAAAAAHHHHAAHHHH";
        }
    } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err('DOCHAZKA_NOT_FOUND_404');
    }
    return $status;
}

# takes class (priv/sched)
sub _get_history {
    my %PH = validate( @_, {
        'class' => { type => SCALAR },         # e.g. 'App::Dochazka::REST::Dispatch::Priv'
        'eid' => { type => SCALAR },     
        'nick' => { type => SCALAR }, 
        'tsrange' => { type => SCALAR|UNDEF }, # e.g. '[ 1969-04-27 08:00, 1971-04-26 08:00 )'
    } );

    my $prop = _prop_from_class( $PH{class} );

    return App::Dochazka::REST::Model::Shared::get_history( 
        $prop, 
        eid => $PH{eid}, 
        nick => $PH{nick}, 
        tsrange => $PH{tsrange} 
    );
}

# takes class (priv/sched), eid (integer) and body (hashref)
sub _put_history {
    my %PH = validate( @_, {
        'class' => { type => SCALAR },         # e.g. 'App::Dochazka::REST::Model::Privhistory'
        'eid' => { type => SCALAR },     
        'body' => { type => HASHREF },
    } );
    $log->debug( "Entering " . __PACKAGE__ . " _put_history with PARAMHASH " . Dumper( \%PH ) );
    my $prop = _prop_from_class( $PH{class} );
    return $CELL->status_err('DOCHAZKA_MALFORMED_400') if not $PH{body}->{'effective'} or not $PH{body}->{$prop};
    my $ho;
    try {
        $ho = $PH{class}->spawn( 
            eid => $PH{eid}, 
            effective => $PH{body}->{'effective'},
            $prop => $PH{body}->{$prop},
        );
    } catch {
        $log->crit($_);
        return $CELL->status_crit("DISPATCH_HISTORY_COULD_NOT_SPAWN", args => [ $_ ] );
    };
    return $ho->insert;
}

# generalized dispatch target for:
#    '/priv/history/phid/:phid'
#    '/schedule/history/shid/:shid'
sub history_by_id {
    my %PH = validate( @_, {
        class => { type => SCALAR },
        method => { type => SCALAR },
        id => { type => SCALAR },
    } );
    my $status = $PH{class}->load_by_id( $PH{id} );
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        return $status->payload->delete if $PH{method} eq 'DELETE';
    }
    return $status;
}


# fetch_by_eid, fetch_by_nick, and fetch_own are shared between attendance intervals
# (Interval.pm) and lock intervals (Lock.pm) - this little routine figures out which
# one we are processing by peeking into the path
sub _determine_interval_or_lock {
    my $path = shift;
    my $type = ( $path =~ m/^\/*interval/ )
        ? "attendance"
        : "lock";
    return $type;
}

# generalized dispatch target for
#    'interval/eid/:eid/:tsrange'
#    'lock/eid/:eid/:tsrange'
sub fetch_by_eid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_fetch_by_eid" ); 
    my ( $eid, $tsrange ) = ( $context->{'mapping'}->{'eid'}, $context->{'mapping'}->{'tsrange'} );

    my $type = _determine_interval_or_lock( $context->{'path'} );
    $log->debug("About to fetch $type intervals for EID $eid in tsrange $tsrange" );

    my $status = $f_dispatch{$type}->( $eid, $tsrange );
    if ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' );
    }
    return $status;
}

# generalized dispatch target for
#    'interval/nick/:nick/:tsrange'
#    'lock/nick/:nick/:tsrange'
sub fetch_by_nick {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_fetch_by_nick" ); 
    my ( $nick, $tsrange ) = ( $context->{'mapping'}->{'nick'}, $context->{'mapping'}->{'tsrange'} );
    $log->debug("About to fetch intervals for nick $nick in tsrange $tsrange" );

    my $type = _determine_interval_or_lock( $context->{'path'} );
    $log->debug("About to fetch $type intervals for nick $nick in tsrange $tsrange" );

    # get EID
    my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $nick );
    if ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' );
    } elsif ( $status->not_ok ) {
        return $status;
    }
    my $eid = $status->payload->{'eid'};
    
    $status = $f_dispatch{$type}->( $eid, $tsrange );
    if ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' );
    }
    return $status;
}

# generalized dispatch target for
#    'interval/self/:tsrange'
#    'lock/self/:tsrange'
sub fetch_own {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::_fetch_own" ); 
    my ( $eid, $tsrange ) = ( $context->{'current'}->{'eid'}, $context->{'mapping'}->{'tsrange'} );

    my $type = _determine_interval_or_lock( $context->{'path'} );
    $log->debug("About to fetch $type intervals for EID $eid (current employee) in tsrange $tsrange" );

    my $status = $f_dispatch{$type}->( $eid, $tsrange );
    if ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' );
    }
    return $status;
}

# generalized dispatch target for
#    'interval/iid' and 'interval/iid/:iid'
#    'lock/lid' and 'lock/lid/:lid'
sub iid_lid {
    my ( $context ) = validate_pos( @_, { type => HASHREF } );
    $log->debug( "Entering " . __PACKAGE__ . "::iid_lid" ); 

    my $type = _determine_interval_or_lock( $context->{'path'} );
    my %idmap = (
        "attendance" => 'iid',
        "lock" => 'lid',
    );

    my $id;
    if ( $context->{'method'} eq 'POST' ) {
        return $CELL->status_err('DOCHAZKA_MALFORMED_400') 
            unless exists $context->{'request_body'}->{ $idmap{$type} };
        $id = $context->{'request_body'}->{ $idmap{$type} };
        return $CELL->status_err('DISPATCH_PARAMETER_BAD_OR_MISSING', 
            args => [ $idmap{$type} ] ) unless $id;
        delete $context->{'request_body'}->{ $idmap{$type} };
    } else {
        $id = $context->{'mapping'}->{ $idmap{$type} };
    }

    # does the ID exist? if so, to whom does it belong?
    my $fn = "load_by_" . $idmap{$type};
    my $status = $id_dispatch{$type}->$fn( $id );
    return $status unless $status->level eq 'OK' or $status->level eq 'NOTICE';
    return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' ) if $status->code eq 'DISPATCH_NO_RECORDS_FOUND';
    my $belongs_eid = $status->payload->{'eid'};

    # this target requires special ACL handling
    my $current_eid = $context->{'current'}->{'eid'};
    my $current_priv = $context->{'current_priv'};
    if (   ( $current_priv eq 'passerby' ) or 
           ( $current_priv eq 'inactive' ) or
           ( $current_priv eq 'active' and $current_eid != $belongs_eid )
    ) {
        return $CELL->status_err( 'DOCHAZKA_FORBIDDEN_403' );
    }

    # it exists and we passed the ACL check, so go ahead and do what we need to do
    if ( $context->{'method'} eq 'GET' ) {
        return $status if $status->code eq 'DISPATCH_RECORDS_FOUND';
    } elsif ( $context->{'method'} =~ m/^(PUT)|(POST)$/ ) {
        return _update_interval( $idmap{$type}, $status->payload, $context->{'request_body'} );
    } elsif ( $context->{'method'} eq 'DELETE' ) {
        $log->notice( "Attempting to delete $type interval " . $status->payload->{ $idmap{$type} } );
        return $status->payload->delete;
    }
    return $CELL->status_crit("Aaaaaaaaaaahhh! Swallowed by the abyss" );
}

# takes two arguments:
# - "$idv" is a string that can be either 'iid' or 'lid'
# - "$int" is an interval object (blessed hashref)
# - "$over" is a hashref with zero or more interval properties and new values
# the values from $over replace those in $int
sub _update_interval {
    my ($idv, $int, $over) = @_;
    $log->debug("Entering " . __PACKAGE__ . "::_update_interval" );
    if ( ref($over) ne 'HASH' ) {
        return $CELL->status_err('DOCHAZKA_MALFORMED_400')
    }
    delete $over->{$idv} if exists $over->{$idv};
    return $int->update if pre_update_comparison( $int, $over );
    return $CELL->status_err('DOCHAZKA_MALFORMED_400');
}

1;
